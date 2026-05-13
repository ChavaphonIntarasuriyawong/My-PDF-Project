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
- OCR fallback for scanned PDFs (Tesseract — English + Thai), feeds TTS when no embedded text layer exists
- Per-book PIN lock with biometric quick-unlock (Face ID / Touch ID / fingerprint, mobile)
- Profile (name + email)
- "Recently Opened" rail backed by Hive (local storage)
- Phone-frame layout on wide web viewports
- External-link reading on web via Supabase Edge Function CORS proxy
- Remote Config feature flag for OCR rollback (`ocr_fallback_enabled`)

---

## Tech Stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart SDK ^3.10.7) |
| State | `flutter_riverpod` |
| Routing | `go_router` (auth-gated redirects + per-book lock gate) |
| Auth + DB | Firebase Auth + Cloud Firestore |
| Feature flags | Firebase Remote Config |
| File storage | Supabase Storage (bucket `pdfs`) |
| CORS proxy | Supabase Edge Function `pdf-proxy` |
| Local storage | Hive (`app_prefs` box) |
| PDF render | `flutter_pdfview` (mobile), `pdfx` (web + thumbnails) |
| PDF text/metadata | `syncfusion_flutter_pdf`, `flutter_pdf_text` |
| OCR (mobile) | `tesseract_ocr` (FFI, Tesseract 4) |
| OCR (web) | Tesseract.js v5 in a Web Worker |
| TTS | `flutter_tts` |
| Biometric (book lock) | `local_auth` |
| Logging | `logger` (with Crashlytics mirror on mobile) |
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
| `firebase_remote_config` | ^5.4.0 | Feature flags (e.g. `ocr_fallback_enabled`). Read via `featureFlagsProvider`. |
| `local_auth` | ^2.3.0 | Biometric prompt for the per-book PIN lock quick-unlock (mobile only). |
| `hive` + `hive_flutter` | ^2.2.3 / ^1.1.0 | Local key-value cache (`app_prefs` box → recent book IDs + OCR text). |
| `flutter_pdfview` | ^1.3.2 | Native PDF rendering on mobile. |
| `pdfx` | ^2.9.0 | Web PDF rendering + thumbnail generation + per-page raster for OCR. |
| `syncfusion_flutter_pdf` | ^27.1.48 | PDF metadata extraction + web text extraction (TTS). |
| `flutter_pdf_text` | ^0.9.0 | Mobile-only PDF text extraction (TTS). |
| `flutter_tts` | ^4.2.0 | Text-to-speech (mobile + web). |
| `tesseract_ocr` | ^0.5.0 | OCR fallback on mobile (Android Tesseract4Android via FFI). |
| `web` | ^1.1.0 | Modern JS interop bridge for the Tesseract.js worker on web. |
| `crypt` | ^4.3.1 | SHA-256-crypt PIN hashing for the per-book lock. |
| `logger` | ^2.4.0 | Structured logging (mirrors errors to Crashlytics on mobile). |
| `dartz` | ^0.10.1 | `Either<Failure, T>` for repository contracts. |
| `http` | ^1.2.2 | Network fetches (PDF bytes via `pdf_fetcher.dart`). |
| `path_provider` | ^2.1.4 | Local FS paths (mobile/desktop only — never on web). |
| `file_picker` | ^8.1.2 | PDF picking from device. |
| `font_awesome_flutter` | ^10.8.0 | Icon set used across UI. |
| `flutter_lints` (dev) | ^6.0.0 | Static analysis ruleset. |
| `integration_test` (dev) | sdk | Integration test harness under `integration_test/`. |

Native plugin gotchas:
- Android `AndroidManifest.xml` needs `<intent action android.intent.action.TTS_SERVICE>` inside `<queries>` (Android 11+ package visibility) for `flutter_tts` to find an engine.
- Android also needs `USE_BIOMETRIC` permission (already declared) for the per-book lock biometric path.
- `flutter_pdf_text` is mobile-only — web text extraction routes through `syncfusion_flutter_pdf` on cached bytes.
- `tesseract_ocr` is mobile-only — web OCR uses Tesseract.js via the conditional import in `lib/features/library/data/ocr_data_source.dart`.
- `path_provider` and `dart:io` `File` must be `kIsWeb`-guarded.

---

## Getting Started

### Prerequisites

- Flutter 3.10+ installed (`flutter doctor`)
- Android Studio or Android emulator (for mobile)
- Chrome (for web)
- Supabase CLI for Edge Function deploy: `npx supabase` (no install needed)

### One-time setup: OCR engine assets

The OCR fallback (scanned PDFs → TTS) ships with empty asset folders. You must populate them before the first build, otherwise OCR will throw at runtime on the first scanned page.

**Mobile** — drop into `assets/tessdata/`:

- `eng.traineddata` from `https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata`
- `tha.traineddata` from `https://github.com/tesseract-ocr/tessdata_best/raw/main/tha.traineddata`

**Web** — drop into `web/ocr/`:

- `tesseract.min.js` and `worker.min.js` from `https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/`
- `tesseract-core-simd.wasm` from `https://cdn.jsdelivr.net/npm/tesseract.js-core@5/`
- Gzipped traineddata into `web/ocr/lang/`: `eng.traineddata.gz`, `tha.traineddata.gz` (gzip the same `tessdata_best` files used on mobile)

The folders are scaffolded with `.gitkeep` only — see the `README.md` inside each folder for the latest URLs.

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

## CI / CD

### CI

`.github/workflows/ci.yml` runs on every push (any branch) and every PR targeting `main`:

- `flutter-ci` (gating) — `dart format --set-exit-if-changed`, `flutter analyze --fatal-infos`, `flutter test --coverage --reporter expanded`. Coverage uploaded as the `lcov-coverage` artifact.

Smoke builds are intentionally omitted: the web build is exercised end-to-end by CD, and the Android toolchain has flaked on hosted runners and is outside the D1 deliverable.

Flutter pinned to `3.38.6`.

### CD

`.github/workflows/cd-web.yml` automates web deploys to Firebase Hosting (project `readtrack-8262c`):

- **Trigger:** push to `main` (live channel) and pull requests targeting `main` (preview channel, auto-expires after 7 days).
- **Steps:** checkout, Flutter `3.38.6`, `flutter pub get`, `flutter build web --release`, then `FirebaseExtended/action-hosting-deploy@v0`.

#### Required GitHub secret

| Secret name | How to obtain |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | Firebase Console -> Project Settings -> Service Accounts -> **Generate new private key**. Paste the entire JSON as the secret value under repo Settings -> Secrets and variables -> Actions. |

#### Manual deploy fallback

If CD is disabled or the secret is unset:

```bash
flutter build web --release
firebase deploy --only hosting
```

#### Known limitation

The deployed web build does **not** include the Tesseract.js binaries under `web/ocr/` (those files are gitignored / `.gitkeep` only). OCR will silently no-op on prod web until those assets are committed or fetched in the workflow. See **One-time setup: OCR engine assets** above for the source URLs.

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
├── core/
│   ├── config/       feature_flags.dart  (Remote Config wrapper + provider)
│   ├── constants/    routes, router
│   ├── errors/       failures
│   ├── local/        recent_books_service, ocr_cache_service, book_unlock_session
│   ├── logging/      app_logger.dart  (structured logger + Crashlytics mirror)
│   ├── network/      pdf_fetcher.dart  (CORS proxy entry point)
│   ├── text/         tts_text_cleaner.dart  (OCR/text normalization for TTS)
│   └── theme/        AppColors, AppTypography, AppTheme
├── features/         auth, library, reader, profile  (data/domain/presentation per feature)
├── shared/           reusable widgets
├── firebase_options.dart
└── main.dart

assets/tessdata/      Mobile OCR traineddata (manual download — see Setup)
web/ocr/              Web OCR worker + WASM + traineddata (manual download — see Setup)

supabase/
└── functions/pdf-proxy/index.ts   <- Deno Edge Function

docs/
├── projectscope.md            <- full architecture blueprint, schema, plugin role map
├── design_tokens.md           <- color + typography reference
├── accessibility.md           <- a11y notes
└── qa/integration_test_matrix.md

test/                 unit + widget + controller + golden tests
integration_test/     end-to-end harness
CLAUDE.md             lean entry point for Claude Code (commands, gotchas, working rules)
firestore.rules       Firestore security rules
firestore.indexes.json
```

---

## Configuration

- `lib/main.dart` — Supabase URL + anon key, Hive box open, `FeatureFlags` initialize + provider override
- `lib/firebase_options.dart` — Firebase config (generated by `flutterfire configure`)
- `lib/core/config/feature_flags.dart` — Remote Config defaults (`_defaults` map) + typed getters
- `lib/core/network/pdf_fetcher.dart` — Edge Function URL for web CORS proxy
- `android/app/src/main/AndroidManifest.xml` — `<intent action TTS_SERVICE>` for Android 11+ TTS engine discovery, `USE_BIOMETRIC` permission
- `assets/tessdata/` and `web/ocr/` — OCR engine assets (see one-time setup above)
- `firestore.rules` / `firestore.indexes.json` — Firestore security rules + indexes

---

## Tests

```bash
flutter test                            # full suite
flutter test integration_test/          # integration harness (needs a device / emulator)
```

Unit, widget, controller, and golden tests under `test/`; end-to-end harness under `integration_test/`. Current baseline: **181 pass, 2 skipped, 0 fail**, `flutter analyze` clean. Fakes match current `FirestoreDataSource` signatures.

---

## Known Limits

- Web reader needs the Edge Function deployed; otherwise external PDF links can't be read (only Supabase URLs work).
- Mobile-only `local://` legacy book links exist for older uploads — not portable across devices. New uploads go straight to Supabase.
- TTS on emulator can be flaky; use a real device or wipe emulator data if it goes silent.
- Firebase Storage is not used. Do not add it — all PDFs go to Supabase.
- **iOS is not yet supported by the OCR pipeline.** The `tesseract_ocr` plugin needs a SwiftyTesseract / libtesseract xcframework wired into `ios/Podfile` — not yet added. Android + web OCR are the supported targets.
- **OCR rollback** — flip `ocr_fallback_enabled` to `false` in Firebase Remote Config to disable the OCR fallback without redeploy.
- Profile-level biometric sign-in was removed; biometric is currently scoped to per-book lock quick-unlock only.
- Outstanding security debts (deferred for demo scope): pdf.js loaded from `cdnjs.cloudflare.com` without SRI, no CSP/COEP headers, Hive cache unencrypted, `tesseract_ocr 0.5.0` upstream unmaintained since 2023.

---

## License

Private project. Not for redistribution.
