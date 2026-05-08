# CLAUDE.md — MyPDF Project Blueprint

> **Read this file completely before writing any code.**
> Single source of truth for all agents working on this project.
> Reflects current code state (lib/) — not aspirational design.

---

## Orchestrator

This file is the **orchestrator**. When a user prompt starts with `audit` (alone or followed by agent names), dispatch in parallel via the Task tool to the relevant subagents under `.claude/agents/`. Each subagent is scoped to one concern; never let one rewrite another's domain.

### Agent registry

| Agent file | Concern |
|---|---|
| `.claude/agents/architect.md` | Clean architecture, layering, provider graph, plugin role uniqueness |
| `.claude/agents/flutter_engineer.md` | UI + Riverpod state + GoRouter wiring + theme tokens |
| `.claude/agents/qa_engineer.md` | `test/` suite, `flutter analyze`, manual flow QA, edge cases |
| `.claude/agents/security.md` | Auth, Firestore rules, Supabase RLS, Edge Function, secrets, XSS, CVEs |
| `.claude/agents/firebase_specialist.md` | Firebase + Supabase datasources, schema, Edge Function, deploys |

### Prompt routing

**Explicit `audit` prefix:**
- `audit` → run **all five** agents in parallel.
- `audit <name1> <name2> ...` → only named agents. Aliases: `architect`, `flutter` / `flutter_engineer`, `qa` / `qa_engineer`, `security`, `firebase` / `firebase_specialist`.
- `audit <feature>` where `<feature>` matches `lib/features/<feature>/` → all five, scoped.

**Auto-routing (no prefix needed):**
Match the user's request against the topic map below. Dispatch matching agents in parallel. If no topic matches OR the task is trivial (single-file edit, one-line fix, conversational question, file read, status check) → handle inline.

| Topic keywords / intent in user prompt | Agents to auto-dispatch |
|---|---|
| add/refactor screen, widget, UI bug, route, navigation, theme, GoRouter, layout, phone-frame, web responsive | `flutter_engineer` |
| Firestore query/schema, books/shelves/notes data, Supabase upload, bucket, Edge Function, CORS proxy, Crashlytics wiring, datasource bug | `firebase_specialist` |
| auth flow, login/register, redirect guard, password handling | `firebase_specialist` + `security` |
| security review, rules, RLS, secrets, CVE, XSS, permissions, public deploy gate | `security` |
| write/fix tests, flutter analyze red, regression, edge case, flow QA | `qa_engineer` |
| layering, clean architecture, provider graph, plugin role, domain leak, structure | `architect` |
| new feature spanning data + UI | `architect` + `flutter_engineer` + `firebase_specialist` |
| pre-merge / pre-release / "is this ready to ship" | all five |

**Single-agent shortcut:** if exactly one agent owns the area and the task is non-trivial implementation, dispatch just that one and proceed. Don't dispatch every time — small reads, quick answers, and conversational turns stay inline.

**State the routing decision** in one line before the Task call(s): e.g. `Routing → flutter_engineer + firebase_specialist (auth flow change).` This lets the user veto with a follow-up.

### Dispatch rules

1. **Parallel only.** Send a single message containing one Task tool call per agent. Do not dispatch sequentially when the agents are independent.
2. **Self-contained prompts.** Each agent starts cold. Always include: target paths, the user's original ask, the exact section of `CLAUDE.md` they must read, and what report shape you expect.
3. **No cross-domain edits.** Architect + security + qa diagnose only. Flutter_engineer + firebase_specialist may edit code, but only inside their listed `What you own` paths.
4. **Conflict resolution.** When two agents recommend opposing changes, surface both verdicts to the user with file:line and pick the architect's call as tiebreaker for structure, security's call as tiebreaker for auth/data exposure.
5. **Aggregation.** After all dispatched agents return, post one consolidated report grouped by severity (Critical / High / Medium / Info), each finding tagged with the agent that found it.

### Example dispatch

User: `audit qa security`
Action: parallel Task calls to `qa_engineer` and `security` only. Then merge their reports. Other agents stay idle.

User: `audit reader`
Action: parallel Task calls to all five with scope `lib/features/reader/`.

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
| Navigation | `go_router` 14.6.3 (auth-gated redirect + per-book lock gate) |
| Firebase bootstrap | `firebase_core` 3.13.1 |
| Auth | `firebase_auth` 5.5.4 |
| DB | `cloud_firestore` 5.6.7 |
| Feature flags | `firebase_remote_config` 5.4.0 |
| File storage | `supabase_flutter` 2.8.4 (bucket `pdfs`) |
| CORS proxy (web) | Supabase Edge Function `pdf-proxy` |
| Crash | `firebase_crashlytics` 4.3.5 (mobile only) |
| Biometric | `local_auth` 2.3.0 (mobile only — per-book lock quick-unlock) |
| Local storage | `hive` 2.2.3 + `hive_flutter` 1.1.0 |
| PDF render mobile | `flutter_pdfview` 1.3.2 |
| PDF render web/thumb | `pdfx` 2.9.0 |
| PDF metadata + web text | `syncfusion_flutter_pdf` 27.1.48 |
| PDF text mobile | `flutter_pdf_text` 0.9.0 |
| TTS | `flutter_tts` 4.2.0 |
| OCR mobile | `tesseract_ocr` 0.5.0 (FFI) |
| OCR web | Tesseract.js v5 in a Web Worker (vendored under `web/ocr/`) |
| Web JS interop | `web` 1.1.0 |
| PIN hashing | `crypt` 4.3.1 (SHA-256-crypt) |
| Logging | `logger` 2.4.0 |
| Functional | `dartz` 0.10.1 |
| Net + FS | `http` 1.2.2, `path_provider` 2.1.4 |
| Picker | `file_picker` 8.1.2 |
| Icons | `font_awesome_flutter` 10.8.0 |
| Lints (dev) | `flutter_lints` 6.0.0 |
| Integration tests (dev) | `integration_test` (sdk) |

> Firebase Storage NOT used. PDFs → Supabase bucket `pdfs`.
> Profile = name + email only. No avatar.

Supabase URL + key wired in `lib/main.dart`. Firebase init via `firebase_options.dart`.

### Plugin Role Map

Single role per plugin — do not duplicate purpose across packages.

| Plugin | Role | Platform scope |
|---|---|---|
| `flutter_riverpod` | App + feature state. No `setState` for shared state. | All |
| `go_router` | Routing + auth-gated redirect + per-book lock gate (`routerProvider`). | All |
| `firebase_core` | One-time `Firebase.initializeApp` in `main.dart`. | All |
| `firebase_auth` | Email/password sign-in/up + auth stream. | All |
| `cloud_firestore` | `users`, `bookshelves`, `books`, `notes` collections. | All |
| `firebase_remote_config` | Feature flags exposed via `featureFlagsProvider` (`ocr_fallback_enabled`, future flags). | All |
| `supabase_flutter` | PDF upload + public URL + Edge Function client. | All |
| `firebase_crashlytics` | Crash reporting. **Skipped on web** via `kIsWeb` guard. | Mobile only |
| `local_auth` | Biometric prompt for per-book lock quick-unlock (`BiometricAuthService`). | Mobile only |
| `hive` / `hive_flutter` | `app_prefs` box → `recent_book_ids` + OCR text cache. | All |
| `flutter_pdfview` | Native PDF reader view. | Mobile only |
| `pdfx` | PDF render + thumbnail generation + per-page raster for OCR. | Web + thumbnails + OCR pipeline |
| `syncfusion_flutter_pdf` | Metadata (`author`, `year`) + web TTS text + bitmap-only-PDF probe. | All |
| `flutter_pdf_text` | TTS source on mobile. | Mobile only |
| `flutter_tts` | Speech engine. Needs `<queries>` intent on Android. | All |
| `tesseract_ocr` | OCR fallback when no embedded text layer (FFI bridge to Tesseract). | Mobile only |
| `web` | JS interop bridge for the Tesseract.js Web Worker. | Web only |
| `crypt` | SHA-256-crypt hashing for the per-book PIN lock (`BookLockHasher`). | All |
| `logger` | Structured logging through `AppLogger` (Crashlytics mirror on mobile). | All |
| `dartz` | `Either<Failure, T>` for repository contracts. | All |
| `http` | PDF byte fetches via `pdf_fetcher.dart`. | All |
| `path_provider` | App docs dir for cached PDFs. **Never call on web.** | Mobile/desktop |
| `file_picker` | PDF picking on new-book screen. | All |
| `font_awesome_flutter` | Icon set. | All |
| `flutter_lints` | Static analysis (dev dep). | — |
| `integration_test` | Integration test harness under `integration_test/` (dev dep). | — |

### Native plugin config

- `android/app/src/main/AndroidManifest.xml` — `<intent action android.intent.action.TTS_SERVICE>` under `<queries>` (Android 11+ package visibility) for `flutter_tts`. Also `USE_BIOMETRIC` permission for the per-book lock biometric path.
- `firebase_options.dart` generated by `flutterfire configure` — do not hand-edit.
- Web build registers `pdfx` via auto-generated `flutter_service_worker.js` (no manual setup).
- OCR engine assets are NOT bundled — `assets/tessdata/` (mobile) and `web/ocr/` (web) ship empty (`.gitkeep`). README documents the manual download URLs (`tessdata_best` traineddata + Tesseract.js worker/WASM).
- iOS OCR not yet wired — needs SwiftyTesseract / libtesseract xcframework Podfile entries (deliberately deferred).

---

## Directory Layout (actual)

```
lib/
├── core/
│   ├── config/      feature_flags.dart        (Remote Config wrapper + featureFlagsProvider)
│   ├── constants/   app_router.dart, app_routes.dart
│   ├── errors/      failures.dart             (Failure, AuthFailure, ServerFailure)
│   ├── local/       recent_books_service.dart, ocr_cache_service.dart, book_unlock_session.dart
│   ├── logging/     app_logger.dart           (logger + Crashlytics mirror)
│   ├── network/     pdf_fetcher.dart          (shared fetch + Supabase Edge proxy)
│   ├── text/        tts_text_cleaner.dart     (whitespace/hyphen/diacritic cleanup for OCR-fed TTS)
│   └── theme/       app_colors.dart, app_typography.dart, app_theme.dart
├── features/
│   ├── auth/
│   │   ├── data/    firebase_auth_data_source.dart, auth_repository_impl.dart, biometric_auth_service.dart
│   │   ├── domain/  auth_repository.dart, user_model.dart
│   │   └── presentation/  login_screen, register_screen, auth_controller, auth_providers
│   ├── library/
│   │   ├── data/    firestore_data_source.dart, pdf_metadata.dart, book_lock_hasher.dart,
│   │   │            ocr_data_source.dart  (+ _io.dart, _web.dart conditional impls)
│   │   ├── domain/  book_model, bookshelf_model, note_model
│   │   └── presentation/  home_screen, shelf_content_screen, new_book_screen, book_info_screen,
│   │                      book_lock_screen, library_controller, library_providers,
│   │                      widgets/ (lock_setup_sheet, ...)
│   ├── reader/
│   │   └── presentation/  reading_screen, note_screen, note_edit_screen
│   └── profile/
│       └── presentation/  profile_screen, edit_profile_screen
├── shared/widgets/  pdf_card, status_badge, app_bottom_nav_bar, app_modal, app_drawer, gradient_button, labeled_text_field
├── firebase_options.dart
└── main.dart

assets/tessdata/                       Mobile OCR traineddata (manual — see README)
web/ocr/                               Web OCR worker + WASM + traineddata (manual — see README)
supabase/functions/pdf-proxy/index.ts  Deno Edge Function (CORS proxy)
firestore.rules / firestore.indexes.json
integration_test/                      Integration test harness
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
| Book lock (PIN gate) | `/book/:id/lock` |
| Profile | `/profile` |
| Edit profile | `/profile/edit` |

`routerProvider` watches `authStateProvider`; redirects unauthenticated → `/login`, authed-on-auth-route → `/home`. Loading state: no redirect (avoids flash).

**Per-book lock gate.** When the matched location is `/book/:id/reading` or `/book/:id/note`, the redirect inspects the cached `bookByIdProvider(:id)` snapshot (`valueOrNull`). If `book.isLocked == true` and `BookUnlockSession.isUnlocked(:id) == false`, the redirect rewrites to `/book/:id/lock?redirect=<encoded original loc>`. `BookLockScreen` clears the gate on success and pushes `redirectTo` via `context.go`. Never hits Firestore mid-redirect — it only reads cached snapshots.

---

## Firestore Schema

```
users/{uid}            { name, email }
bookshelves/{shelfId}  { name, ownerId, createdAt(ISO) }
books/{bookId}         { title, link, totalPages, currentPage, progress, status, shelfId, ownerId,
                         lastReadAt(ISO), author?, year?, needsOcr, isLocked, lockHash? }
notes/{noteId}         { bookId, title, content, updatedAt(ISO) }
```

`status` ∈ `reading | on_hold | finished`. `progress` = `currentPage / totalPages * 100`.
Note: dates stored as ISO 8601 strings (not Firestore `Timestamp`).

`book.author` + `book.year` extracted from PDF metadata via Syncfusion (`pdf_metadata.dart`).

`book.needsOcr` (bool, default `false`) — set at upload time by the `_isBitmapOnlyPdf` heuristic in `new_book_screen.dart` when the PDF has no embedded text layer. Lets the reader skip the text-extraction probe and route straight to the OCR pipeline.

`book.isLocked` (bool, default `false`) + `book.lockHash` (string?, nullable) — per-book PIN lock. `lockHash` is a SHA-256-crypt modular crypt string (`$5$<salt>$<hash>`). The raw PIN is never stored.

### Cascades
- Delete shelf → books unshelved (`shelfId = ''`), shelf doc deleted.
- Delete book → notes deleted (batch) + Supabase object purged + local cache/thumb purged + recents entry removed + OCR cache purged (`OcrCacheService.purgeBook`).
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

Box `app_prefs` opened in `main.dart` after Firebase init. Two services own keys in this box; nothing else writes.

| Key | Type | Owner service | Purpose |
|---|---|---|---|
| `recent_book_ids` | `List<String>` | `RecentBooksService` | Most-recent-first book IDs, capped at 10 |
| `ocr_v1_{bookId}_{pageIndex}` | `String` | `OcrCacheService` | Cleaned OCR text for one page (0-based pageIndex). Schema-versioned (`v1`) so a future engine swap can cut a new namespace. |

`RecentBooksService` (`lib/core/local/recent_books_service.dart`):
- `markOpened(bookId)` called from `ReadingScreen.initState` — dedupes + bumps to front
- `remove(bookId)` called from `LibraryController.deleteBook`
- `watch()` reactive stream

`OcrCacheService` (`lib/core/local/ocr_cache_service.dart`):
- `get(bookId, pageIndex)` synchronous read, returns `null` on miss
- `put(bookId, pageIndex, text)` best-effort persist (failures swallowed + logged)
- `purgeBook(bookId)` called from `LibraryController.deleteBook` — drops every `ocr_v1_<bookId>_*` key
- `purgeAll()` admin/debug helper

Providers in `library_providers.dart`:
- `recentBooksServiceProvider` — service instance
- `recentBookIdsProvider` — `StreamProvider<List<String>>`
- `recentBooksProvider` — joins ids ↔ `allBooksProvider`, drops missing, preserves recency
- `ocrCacheServiceProvider` — `OcrCacheService` instance

Surfaced on home screen as horizontal "Recently Opened" rail (hidden when empty, respects shelf filter).

`BookUnlockSession` (`lib/core/local/book_unlock_session.dart`) is in-memory only — process lifetime, never persisted, exposed via `bookUnlockSessionProvider`. Killing/restarting the app re-locks every book.

---

## Provider graph (top-level)

| Provider | Type | Purpose |
|---|---|---|
| `featureFlagsProvider` | `Provider<FeatureFlags>` | Remote Config wrapper (overridden in `main.dart`). Read flags through this only. |
| `firestoreDataSourceProvider` | `Provider<FirestoreDataSource>` | Datasource singleton |
| `recentBooksServiceProvider` | `Provider<RecentBooksService>` | Hive recents service |
| `bookUnlockSessionProvider` | `Provider<BookUnlockSession>` | In-memory unlocked-book set |
| `recentBookIdsProvider` | `StreamProvider<List<String>>` | LRU recent IDs |
| `recentBooksProvider` | `Provider<List<BookModel>>` | Joins recents with `allBooksProvider` |
| `shelvesProvider` | `StreamProvider<List<BookshelfModel>>` | All shelves for current uid |
| `booksByShelfProvider` | `StreamProvider.family<List<BookModel>, String>` | Books for a single shelf |
| `allBooksProvider` | `StreamProvider<List<BookModel>>` | All books for current uid |
| `bookByIdProvider` | `StreamProvider.family<BookModel?, String>` | Single book stream (used by lock gate) |
| `notesByBookProvider` | `StreamProvider.family<List<NoteModel>, String>` | Notes for a book |
| `noteByIdProvider` | `FutureProvider.family<NoteModel?, String>` | One-shot note lookup |
| `userNotesCountProvider` | `StreamProvider<int>` | Aggregated notes count (chunked `whereIn`) |
| `pdfPathProvider` | `FutureProvider.family<String, String>` | Local file path (mobile) or URL (web) for a book link |
| `pdfPageImageProvider` | `FutureProvider.family<Uint8List?, ({String url, int pageIndex})>` | Renders a single PDF page to JPEG (cached on mobile). Invalidated by OCR pipeline post-recognise. |
| `pdfThumbnailProvider` | `FutureProvider.family<Uint8List?, String>` | Thin wrapper for page 0 of `pdfPageImageProvider` |
| `ocrCacheServiceProvider` | `Provider<OcrCacheService>` | Hive-backed OCR text cache |
| `ocrDataSourceProvider` | `Provider<OcrDataSource>` | Platform-resolved engine via conditional import; disposed in `ref.onDispose` |
| `ocrPageTextProvider` | `FutureProvider.family<String, ({String bookId, String url, int pageIndex})>` | Cache → render → OCR → clean → cache → return; invalidates `pdfPageImageProvider` post-run |
| `bookOcrProgressProvider` | `StateProvider<({int done, int total})?>` | Background pre-OCR progress chip in reader app bar |

---

## OCR pipeline

Trigger: hybrid. When TTS is requested for a page, `ReadingScreen` first tries the embedded text layer (Syncfusion / `flutter_pdf_text`); if empty AND the book is `needsOcr || ocr_fallback_enabled`, it routes through `ocrPageTextProvider`. Background pre-OCR sweep populates the cache for adjacent pages.

Engines (selected at compile time via conditional import in `lib/features/library/data/ocr_data_source.dart`):
- Mobile: `tesseract_ocr` (Tesseract4Android FFI on Android; iOS not yet wired).
- Web: Tesseract.js v5 in a Web Worker; assets vendored under `web/ocr/`.
- Languages: `eng+tha`, `tessdata_best`, OEM=1 LSTM-only.

Cache key: `ocr_v1_{bookId}_{pageIndex}` in the Hive `app_prefs` box. `OcrCacheService` is the only writer.

Page raster: `pdfPageImageProvider` renders to JPEG clamped to 1600 px on the long edge to bound memory during long-document pre-OCR sweeps. The provider is invalidated immediately after recognition (success or failure) so a 200-page scan doesn't pin gigabytes of JPEG bytes in the family cache.

Output cleaning: `lib/core/text/tts_text_cleaner.dart` (`cleanForTts`) normalizes whitespace + hyphenation before the string reaches `flutter_tts`.

Kill switch: `featureFlags.ocrFallbackEnabled` (Remote Config key `ocr_fallback_enabled`, default `true`, 1 h TTL). Flip to `false` in Firebase Console to disable without redeploy.

---

## Per-book PIN lock

Hashing: `BookLockHasher` uses `crypt` (SHA-256-crypt, modular crypt format `$5$<salt>$<hash>`). Salt generated per `hash()`. Verification swallows `FormatException` / `RangeError` → returns `false` so malformed stored hashes surface as "incorrect PIN" rather than crashes.

Storage: hash lives in `book.lockHash`; `book.isLocked` flips on/off the gate without rewriting the hash so re-enabling restores the previous PIN.

Session: `BookUnlockSession` (in-memory `Set<String>`). `routerProvider` reads it via `bookUnlockSessionProvider` to decide whether to redirect to `/book/:id/lock`. Cleared on logout.

Biometric quick-unlock: `BiometricAuthService` (in `lib/features/auth/data/`) wraps `local_auth`. Profile-level biometric sign-in is removed — service is retained ONLY for this book-lock path.

UI: `BookLockScreen` is a 3x4 numpad with empty/filled-dot indicator. Wrong-PIN cooldown (5 attempts → 30 s lockout) is screen-local ephemeral state (`setState`) per the UI-local exception in `CLAUDE.md`. `lock_setup_sheet.dart` (under `presentation/widgets/`) drives initial PIN setup from book info.

---

## Feature flags

`FeatureFlags` (`lib/core/config/feature_flags.dart`) wraps `firebase_remote_config`:
- Defaults registered in `_defaults` map → used when no remote value has activated yet.
- `initialize()` is called once in `main.dart` before `runApp`. Errors are caught + logged → never wedge startup.
- 1 h TTL, 10 s fetch timeout.
- Read through `featureFlagsProvider` only — provider is overridden inside `ProviderScope` so every `ref.read` returns the same singleton.

Active flags:

| Key | Default | Effect |
|---|---|---|
| `ocr_fallback_enabled` | `true` | Master switch for the OCR fallback pipeline. Flip `false` to hide OCR without redeploy. |

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
| Test suite (`test/`) | UPDATED — 181 pass, 2 skipped, 0 fail; fakes match current `FirestoreDataSource` signatures |
| Integration test harness (`integration_test/`) | DONE — scaffolded under `integration_test/app_test.dart` |
| OCR fallback (mobile + web, eng+tha) | DONE — Tesseract via FFI on mobile, Tesseract.js Web Worker on web; gated by `ocr_fallback_enabled`. iOS not yet wired (Podfile entries deferred). |
| Per-book PIN lock + biometric quick-unlock | DONE — SHA-256-crypt hashing, GoRouter gate, in-memory session |
| Feature flag system (Firebase Remote Config) | DONE — `FeatureFlags` wrapper + `featureFlagsProvider`. First flag: `ocr_fallback_enabled` (master switch for OCR fallback). |
| Profile-level biometric sign-in | REMOVED — `local_auth` retained only for per-book lock |

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
- `tesseract_ocr` is mobile only — web OCR uses Tesseract.js via the conditional `_web.dart` impl. Never import the `_io.dart` / `_web.dart` files directly; depend on `OcrDataSource` + `createOcrDataSource()`.
- TTS on Android needs `<intent action TTS_SERVICE>` inside `<queries>` in `AndroidManifest.xml` (Android 11+ package visibility).
- Web TTS: poll `getVoices` (Chrome/Edge populate async), call `_trySetWebVoice` again on first user gesture if init missed it.
- Always go through `fetchPdfBytes` (not `http.get` directly) when fetching PDF data — guarantees the web CORS proxy is used.
- Read feature flags through `featureFlagsProvider`. Never call `FirebaseRemoteConfig.instance` directly — it bypasses test overrides + the singleton lifecycle.
- Hive `app_prefs` writes only via `RecentBooksService` or `OcrCacheService`. New keys require a new dedicated service.
- Don't reintroduce a profile-level biometric sign-in toggle — biometric scope is per-book lock only.

### Pre-existing security debts (deliberately deferred for demo scope)
- `web/index.html` loads pdf.js from `cdnjs.cloudflare.com` without SRI.
- No CSP/COEP/COOP headers configured (Tesseract.js SIMD WASM degrades silently without `Cross-Origin-Embedder-Policy: require-corp`).
- Hive `app_prefs` cache is unencrypted.
- `tesseract_ocr 0.5.0` upstream has been unmaintained since 2023.
