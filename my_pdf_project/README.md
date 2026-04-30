# MyPDF

PDF reading progress tracker. Save PDFs by upload or link, organize them into bookshelves, track reading progress, write notes, and listen via text-to-speech.

Flutter app targeting **Android (primary)** and **Web (secondary)**.

---

## Features

- Email/password auth (Firebase)
- Bookshelves + books CRUD (Firestore, real-time streams)
- PDF upload (Supabase Storage) or paste-link import
- Reader with auto-resume to last page + progress percentage
- Per-book notes (auto-named `Note (N)` if title empty)
- Text-to-speech of current page (mobile + web)
- Profile (name + email)
- "Recently Opened" rail backed by Hive (local storage)
- Phone-frame layout on wide web viewports
- External-link reading on web via Supabase Edge Function CORS proxy

---

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart SDK ^3.10.7) |
| State | `flutter_riverpod` |
| Routing | `go_router` (auth-gated redirects) |
| Auth + DB | Firebase Auth + Cloud Firestore |
| File storage | Supabase Storage (bucket `pdfs`) |
| CORS proxy | Supabase Edge Function `pdf-proxy` |
| Local storage | Hive |
| PDF render | `flutter_pdfview` (mobile), `pdfx` (web + thumbnails) |
| PDF text/metadata | `syncfusion_flutter_pdf`, `flutter_pdf_text` |
| TTS | `flutter_tts` |
| Crash | `firebase_crashlytics` (mobile only) |

Architecture: Clean (data / domain / presentation per feature).

For full architecture rules, schema, and gotchas: see [`docs/projectscope.md`](./docs/projectscope.md). Lean entry point for Claude Code: [`CLAUDE.md`](./CLAUDE.md).

---

## Plugins (Flutter packages)

Full dependency list from `pubspec.yaml`. Each package has a defined role — do not swap without checking `CLAUDE.md`.

| Package | Version | Role |
|---|---|---|
| `flutter_riverpod` | ^2.6.1 | App state management. No `setState` for shared state. |
| `go_router` | ^14.6.3 | Declarative routing + auth-gated redirect guard. |
| `firebase_core` | ^3.13.1 | Firebase init bootstrap. |
| `firebase_auth` | ^5.5.4 | Email/password auth. |
| `cloud_firestore` | ^5.6.7 | Books, shelves, notes, users docs. |
| `supabase_flutter` | ^2.8.4 | PDF storage (`pdfs` bucket) + Edge Function calls. |
| `firebase_crashlytics` | ^4.3.5 | Crash reporting (mobile only — skipped on web). |
| `hive` + `hive_flutter` | ^2.2.3 / ^1.1.0 | Local key-value cache (`app_prefs` box → recent book IDs). |
| `flutter_pdfview` | ^1.3.2 | Native PDF rendering on mobile. |
| `pdfx` | ^2.9.0 | Web PDF rendering + thumbnail generation. |
| `syncfusion_flutter_pdf` | ^27.1.48 | PDF metadata extraction + web text extraction (TTS). |
| `flutter_pdf_text` | ^0.9.0 | Mobile-only PDF text extraction (TTS). |
| `flutter_tts` | ^4.2.0 | Text-to-speech (mobile + web). |
| `dartz` | ^0.10.1 | `Either<Failure, T>` for repository contracts. |
| `http` | ^1.2.2 | Network fetches (PDF bytes via `pdf_fetcher.dart`). |
| `path_provider` | ^2.1.4 | Local FS paths (mobile/desktop only — never on web). |
| `file_picker` | ^8.1.2 | PDF picking from device. |
| `font_awesome_flutter` | ^10.8.0 | Icon set used across UI. |
| `flutter_lints` (dev) | ^6.0.0 | Static analysis ruleset. |

Native plugin gotchas:
- Android `AndroidManifest.xml` needs `<intent action android.intent.action.TTS_SERVICE>` inside `<queries>` (Android 11+ package visibility) for `flutter_tts` to find an engine.
- `flutter_pdf_text` is mobile-only — web text extraction routes through `syncfusion_flutter_pdf` on cached bytes.
- `path_provider` and `dart:io` `File` must be `kIsWeb`-guarded.

---

## Getting Started

### Prerequisites

- Flutter 3.10+ installed (`flutter doctor`)
- Android Studio or Android emulator (for mobile)
- Chrome (for web)
- Supabase CLI for Edge Function deploy: `npx supabase` (no install needed)

### Run

```bash
flutter pub get
flutter run                 # mobile (default device)
flutter run -d chrome       # web
```

### Build

```bash
flutter build apk --release          # Android
flutter build web --release          # Web → build/web/
```

### Firebase Hosting deploy (web)

```bash
flutter build web --release
firebase deploy --only hosting
```

---

## Supabase Edge Function (CORS Proxy)

Deployed function lives in `supabase/functions/pdf-proxy/index.ts`.
Required for web users to read PDFs from external hosts (browser CORS otherwise blocks fetches).

### Deploy

```bash
npx supabase login
npx supabase link --project-ref <YOUR_PROJECT_REF>
npx supabase functions deploy pdf-proxy --no-verify-jwt
```

After deploy, set the function URL in `lib/core/network/pdf_fetcher.dart`:

```dart
const String kCorsProxyBase =
    'https://<project-ref>.supabase.co/functions/v1/pdf-proxy';
```

Mobile bypasses the proxy entirely.

---

## Project Layout

```
lib/
├── core/          theme, errors, constants, local (Hive), network (proxy)
├── features/      auth, library, reader, profile  (data/domain/presentation per feature)
├── shared/        reusable widgets
├── firebase_options.dart
└── main.dart

supabase/
└── functions/pdf-proxy/index.ts   ← Deno Edge Function

test/              widget + controller tests
```

---

## Configuration

- `lib/main.dart` — Supabase URL + anon key
- `lib/firebase_options.dart` — Firebase config (generated by `flutterfire configure`)
- `lib/core/network/pdf_fetcher.dart` — Edge Function URL for web CORS proxy
- `android/app/src/main/AndroidManifest.xml` — `<intent action TTS_SERVICE>` for Android 11+ TTS engine discovery

---

## Tests

```bash
flutter test
```

Widget + controller tests under `test/`. Fakes match current `FirestoreDataSource` signatures.

---

## Known Limits

- Web reader needs the Edge Function deployed; otherwise external PDF links can't be read (only Supabase URLs work).
- Mobile-only `local://` legacy book links exist for older uploads — not portable across devices. New uploads go straight to Supabase.
- TTS on emulator can be flaky; use a real device or wipe emulator data if it goes silent.
- Firebase Storage is not used. Do not add it — all PDFs go to Supabase.

---

## License

Private project. Not for redistribution.
