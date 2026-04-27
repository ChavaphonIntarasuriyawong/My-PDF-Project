# CLAUDE.md — MyPDF Project Blueprint

> **Read this file completely before writing any code.**
> Single source of truth for all agents working on this project.
> Reflects current code state (lib/) — not aspirational design.

---

## App Overview

| Field | Value |
|---|---|
| App Name | MyPDF |
| Type | Flutter + Firebase + Supabase |
| Platforms | Android (primary), Web (secondary), iOS/desktop scaffolded |
| Purpose | Save PDFs (link or upload), organize into bookshelves, track reading progress, write notes, TTS read-aloud |

---

## Tech Stack (matches `pubspec.yaml`)

| Layer | Package |
|---|---|
| Framework | Flutter SDK ^3.10.7 |
| State | `flutter_riverpod` 2.6.1 |
| Navigation | `go_router` 14.6.3 (auth-gated redirect) |
| Auth | `firebase_auth` 5.5.4 |
| DB | `cloud_firestore` 5.6.7 |
| File storage | `supabase_flutter` 2.8.4 (bucket `pdfs`) |
| CORS proxy (web) | Supabase Edge Function `pdf-proxy` |
| Crash | `firebase_crashlytics` 4.3.5 (mobile only) |
| Local storage | `hive` 2.2.3 + `hive_flutter` 1.1.0 |
| PDF render mobile | `flutter_pdfview` 1.3.2 |
| PDF render web/thumb | `pdfx` 2.9.0 |
| PDF metadata + web text | `syncfusion_flutter_pdf` 27.1.48 |
| PDF text mobile | `flutter_pdf_text` 0.9.0 |
| TTS | `flutter_tts` 4.2.0 |
| Functional | `dartz` 0.10.1 |
| Net + FS | `http` 1.2.2, `path_provider` 2.1.4 |
| Picker | `file_picker` 8.1.2 |
| Icons | `font_awesome_flutter` 10.8.0 |

> Firebase Storage NOT used. PDFs → Supabase bucket `pdfs`.
> Profile = name + email only. No avatar.

Supabase URL + key wired in `lib/main.dart`. Firebase init via `firebase_options.dart`.

---

## Directory Layout (actual)

```
lib/
├── core/
│   ├── constants/   app_router.dart, app_routes.dart
│   ├── errors/      failures.dart  (Failure, AuthFailure, ServerFailure)
│   ├── local/       recent_books_service.dart  (Hive box `app_prefs`)
│   ├── network/     pdf_fetcher.dart  (shared fetch + Supabase Edge proxy)
│   └── theme/       app_colors.dart, app_typography.dart, app_theme.dart
├── features/
│   ├── auth/
│   │   ├── data/    firebase_auth_data_source.dart, auth_repository_impl.dart
│   │   ├── domain/  auth_repository.dart, user_model.dart
│   │   └── presentation/  login_screen, register_screen, auth_controller, auth_providers
│   ├── library/
│   │   ├── data/    firestore_data_source.dart, pdf_metadata.dart
│   │   ├── domain/  book_model, bookshelf_model, note_model
│   │   └── presentation/  home_screen, shelf_content_screen, new_book_screen, book_info_screen, library_controller, library_providers
│   ├── reader/
│   │   └── presentation/  reading_screen, note_screen, note_edit_screen
│   └── profile/
│       └── presentation/  profile_screen, edit_profile_screen
├── shared/widgets/  pdf_card, status_badge, app_bottom_nav_bar, app_modal, app_drawer, gradient_button, labeled_text_field
├── firebase_options.dart
└── main.dart

supabase/functions/pdf-proxy/index.ts   ← Deno Edge Function, CORS proxy
```

### Domain Rules (still enforced)
- Zero `flutter/`, `firebase_*`, `supabase_*` imports in `domain/`.
- Domain types: plain Dart, `Either<Failure, T>` for repository contracts.

---

## Routes (`AppRoutes` + `routerProvider`)

| Screen | Route |
|---|---|
| Login | `/login` |
| Register | `/register` |
| Home | `/home` |
| Shelf content | `/shelf/:id` |
| New book | `/book/new` |
| Book info | `/book/:id` |
| Reading | `/book/:id/reading` |
| Note | `/book/:id/note` |
| Profile | `/profile` |
| Edit profile | `/profile/edit` |

`routerProvider` watches `authStateProvider`; redirects unauthenticated → `/login`, authed-on-auth-route → `/home`. Loading state: no redirect (avoids flash).

---

## Firestore Schema

```
users/{uid}            { name, email }
bookshelves/{shelfId}  { name, ownerId, createdAt(ISO) }
books/{bookId}         { title, link, totalPages, currentPage, progress, status, shelfId, ownerId, lastReadAt(ISO), author?, year? }
notes/{noteId}         { bookId, title, content, updatedAt(ISO) }
```

`status` ∈ `reading | on_hold | finished`. `progress` = `currentPage / totalPages * 100`.
Note: dates stored as ISO 8601 strings (not Firestore `Timestamp`).

`book.author` + `book.year` extracted from PDF metadata via Syncfusion (`pdf_metadata.dart`).

### Cascades
- Delete shelf → books unshelved (`shelfId = ''`), shelf doc deleted.
- Delete book → notes deleted (batch) + Supabase object purged + local cache/thumb purged + recents entry removed.
- `deleteBook` returns deleted `book.link` so controller can purge storage/cache.

### Notes count
`watchUserNotesCount` chunks `bookIds` by 30 (Firestore `whereIn` limit), merges streams.

---

## Supabase

### Storage
```
Bucket : pdfs (public)
Path   : {uid}/{millis}.pdf
```
Auth rule: user writes only under their own `{uid}/`.
Upload via `uploadBinary(path, bytes, FileOptions(contentType: 'application/pdf'))`.
Public URL via `getPublicUrl(path)` saved as `book.link`.

### Edge Function `pdf-proxy`
File: `supabase/functions/pdf-proxy/index.ts` (Deno).
Deployed via `npx supabase functions deploy pdf-proxy --no-verify-jwt`.
Endpoint: `https://wtjwmwisitohlzyinoaf.supabase.co/functions/v1/pdf-proxy?url=<encoded URL>`.
Returns upstream PDF bytes with `Access-Control-Allow-Origin: *` so the web build can read external PDFs (bypasses browser CORS). Mobile bypasses the proxy entirely.

---

## Network Layer (`lib/core/network/pdf_fetcher.dart`)

`fetchPdfBytes(url)` is the single entry point used by reading screen + thumbnail provider:

| Caller context | Path |
|---|---|
| Mobile | Direct `http.get` (no CORS) |
| Web + `*.supabase.co/...` URL | Direct `http.get` (Supabase CORS allows) |
| Web + external host | Routes through `kCorsProxyBase` (Edge Function) |

`kCorsProxyBase` constant in this file points at the deployed Edge Function URL.

---

## PDF Path Resolution (`pdfPathProvider`)

Family provider keyed by `book.link`. Returns local file path or remote URL depending on context:

| Context | Behavior |
|---|---|
| Web | Returns URL as-is (reader/thumbnail then call `fetchPdfBytes`). `local://` rejected. |
| Mobile + remote URL | Downloads to `appDocs/pdf_{hash}.pdf`, validates `%PDF-` signature in first 1100 bytes, caches. |
| Mobile + `local://` | Reads from `appDocs/local_pdfs/{filename}`. Legacy path — new uploads go to Supabase. |

Reading screen uses `flutter_pdfview` (mobile) or web fallback that fetches bytes + renders via pdfx.

---

## Local Storage (Hive)

Box `app_prefs` opened in `main.dart` after Firebase init.

| Key | Type | Purpose |
|---|---|---|
| `recent_book_ids` | `List<String>` | Most-recent-first book IDs, capped at 10 |

`RecentBooksService` (`lib/core/local/recent_books_service.dart`):
- `markOpened(bookId)` called from `ReadingScreen.initState` — dedupes + bumps to front
- `remove(bookId)` called from `LibraryController.deleteBook`
- `watch()` reactive stream

Providers in `library_providers.dart`:
- `recentBooksServiceProvider` — service instance
- `recentBookIdsProvider` — `StreamProvider<List<String>>`
- `recentBooksProvider` — joins ids ↔ `allBooksProvider`, drops missing, preserves recency

Surfaced on home screen as horizontal "Recently Opened" rail (hidden when empty, respects shelf filter).

---

## Web Layout

`MyPdfApp` (`main.dart`) injects `_PhoneFrame` via `MaterialApp.router(builder:)`:
- Viewport ≥ 600 px → centered 412×896 frame, rounded 28 px, shadow on `surfaceMuted` background.
- Viewport < 600 px → full-width pass-through (real mobile browser).
- Mobile/desktop native: untouched.

---

## Implementation State

| Area | Status |
|---|---|
| Auth (login/register/logout, redirect guard) | DONE |
| Firestore CRUD shelves/books/notes | DONE |
| Theme (AppColors, AppTypography Manrope/Inter via system fonts) | DONE |
| New book — link import | DONE — mobile probes URL+metadata; web skips probe |
| New book — file upload | DONE — Supabase Storage, mobile + web |
| Reading screen + progress save + auto-jump | DONE |
| Web reader page tracking (viewport center + bottom snap) | DONE |
| TTS mobile (`flutter_pdf_text`) | DONE — needs `<intent TTS_SERVICE>` query in AndroidManifest |
| TTS web (Syncfusion bytes + voiceschanged poll) | DONE — interrupt errors ignored |
| Web external link reading via Edge Function proxy | DONE |
| Web thumbnail via Edge Function proxy | DONE |
| Notes per book (auto-name `Note (N)` on empty title) | DONE |
| Note delete UX (close vs trash icons separated) | DONE |
| Profile + edit (empty-name guard) | DONE |
| Recently Opened rail (Hive) | DONE |
| Storage cleanup on book delete (Supabase + cache) | DONE |
| Crashlytics wired (skipped on web) | DONE |
| Phone-frame on web wide viewports | DONE |
| Test suite (`test/`) | UPDATED — fakes match current `FirestoreDataSource` signatures |

---

## Common Mistakes — Avoid

- No `setState` for app state (UI-local only OK). Use Riverpod.
- No Firebase/Supabase calls in widgets — go through datasources.
- No hardcoded colors/fonts — use `AppColors`/`AppTypography`.
- No `Navigator.push` — use GoRouter.
- No Firebase Storage — Supabase only.
- No avatar fields — name + email only.
- No `dart:io` `File` on web paths (`kIsWeb` guard required for any FS code).
- `path_provider` is mobile/desktop only. Don't call on web.
- `flutter_pdf_text` is mobile only — web text extraction goes through Syncfusion + cached bytes.
- TTS on Android needs `<intent action TTS_SERVICE>` inside `<queries>` in `AndroidManifest.xml` (Android 11+ package visibility).
- Web TTS: poll `getVoices` (Chrome/Edge populate async), call `_trySetWebVoice` again on first user gesture if init missed it.
- Always go through `fetchPdfBytes` (not `http.get` directly) when fetching PDF data — guarantees the web CORS proxy is used.
