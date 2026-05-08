# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **`docs/projectscope.md`** holds the full blueprint (schema, plugin role map, route table, every gotcha). Read it before non-trivial work. This file is the lean entry point.

---

## Commands

```bash
flutter pub get                                  # install deps
flutter analyze                                  # static analysis (must pass before merge)
flutter test                                     # full test suite
flutter test test/screens/reading_screen_test.dart   # single file
flutter test --plain-name "deletes book"         # single test by name
flutter run                                      # mobile default device
flutter run -d chrome                            # web
flutter build apk --release
flutter build web --release
firebase deploy --only hosting                   # web → Firebase Hosting (after build)
npx supabase functions deploy pdf-proxy --no-verify-jwt   # CORS proxy
```

---

## Architecture (big picture)

**Clean architecture per feature.** Each `lib/features/<name>/` has `data/` (Firebase/Supabase datasources, repository impls), `domain/` (plain Dart models, repository interfaces, `Either<Failure, T>` contracts via `dartz`), `presentation/` (screens + Riverpod controllers/providers). `reader/` and `profile/` are presentation-only — they reuse `library/` data + domain.

**State + nav:** `flutter_riverpod` for all shared state (no `setState` for app state). `go_router`'s `routerProvider` watches `authStateProvider` and redirects unauth → `/login`, auth-on-auth-route → `/home`.

**Two backends, distinct roles:**
- **Firebase** = Auth + Firestore (`users`, `bookshelves`, `books`, `notes` — dates as ISO 8601 strings, not `Timestamp`) + Crashlytics (mobile only, `kIsWeb` guard in `main.dart`).
- **Supabase** = Storage bucket `pdfs` (path `{uid}/{millis}.pdf`) + Edge Function `pdf-proxy` (Deno, in `supabase/functions/pdf-proxy/`) for web CORS bypass.
- Firebase Storage is **not** used.

**PDF pipeline (split by platform):**
- `lib/core/network/pdf_fetcher.dart` → `fetchPdfBytes(url)` is the single network entry. Mobile = direct `http.get`. Web + supabase host = direct. Web + external host = via `kCorsProxyBase` Edge Function. Always use this — never call `http.get` directly for PDFs.
- `pdfPathProvider` (family, keyed by `book.link`) returns local file path on mobile (downloads + validates `%PDF-` signature, caches under `appDocs/pdf_{hash}.pdf`) or URL on web.
- Render: `flutter_pdfview` mobile, `pdfx` web + thumbnails.
- Metadata (`author`, `year`): `syncfusion_flutter_pdf` via `lib/features/library/data/pdf_metadata.dart`.
- TTS text source: `flutter_pdf_text` mobile, Syncfusion bytes web.

**Cascading deletes** (in `LibraryController.deleteBook`): batch delete notes → purge Supabase object → clear local cache/thumb → remove from Hive recents → purge Hive OCR cache (`OcrCacheService.purgeBook`). `deleteBook` returns the book's `link` to enable storage purge.

**Local cache (Hive):** box `app_prefs` opened in `main.dart`. Two services own keys in this box, nothing else writes:
- `RecentBooksService` (`lib/core/local/recent_books_service.dart`) → `recent_book_ids` (cap 10, LRU dedupe). Surfaced as horizontal "Recently Opened" rail.
- `OcrCacheService` (`lib/core/local/ocr_cache_service.dart`) → `ocr_v1_{bookId}_{pageIndex}` (per-page OCR text, schema-versioned for future engine swaps).

**Web layout:** `MyPdfApp` injects `_PhoneFrame` via `MaterialApp.router(builder:)`. Viewport ≥600 px → centered 412×896 phone frame. <600 px → pass-through.

**OCR fallback (mobile + web).** Scanned PDFs (no embedded text layer) route through Tesseract for TTS. Mobile = `tesseract_ocr` (FFI). Web = Tesseract.js v5 in a Web Worker. Languages: English + Thai (`tessdata_best`, OEM=1 LSTM-only). Trigger is hybrid — lazy on first read of a page plus a background pre-OCR sweep. `BookModel.needsOcr` is set at upload time by the `_isBitmapOnlyPdf` heuristic in `new_book_screen.dart`, so the reader skips the text-extraction probe and routes straight to OCR. Gated by Remote Config flag `ocr_fallback_enabled` (default true, 1 h TTL).

**Per-book PIN lock.** Optional per-book gate. PIN hashed with SHA-256-crypt (`lib/features/library/data/book_lock_hasher.dart`) — raw PIN never stored. On entry to `/book/:id/reading` or `/book/:id/note` the GoRouter redirect inspects `book.isLocked` and the in-memory `BookUnlockSession`; if locked + not-yet-unlocked, the user is sent to `BookLockScreen` (numpad + biometric quick-unlock via `BiometricAuthService`). The unlocked-set is process-lifetime only — kill / restart re-locks every book.

**Feature flag system established.** `featureFlagsProvider` (overridden in `main.dart` with the singleton built before `runApp`) wraps `firebase_remote_config`. `ocr_fallback_enabled` is the first live flag and satisfies the submission requirement. New flags go in `FeatureFlags._defaults` and are read through the provider — never call `FirebaseRemoteConfig.instance` directly.

---

## Subagent orchestration (mandatory)

This repo uses 5 scoped subagents under `.claude/agents/`. **Dispatch in parallel via the Task tool** for any non-trivial task — do not handle inline.

| Agent | Owns |
|---|---|
| `architect` | Layering, provider graph, plugin role boundaries (diagnose only) |
| `flutter_engineer` | Screens, controllers, providers, GoRouter, theme, kIsWeb branching (edits) |
| `firebase_specialist` | Firestore queries/schema, Supabase upload, Edge Function, datasources (edits) |
| `qa_engineer` | `test/` suite, `flutter analyze`, manual flow QA (diagnose + test edits) |
| `security` | Auth, Firestore rules, RLS, CORS proxy, secrets, CVEs (diagnose only) |

**Routing:** see `docs/projectscope.md` § Orchestrator for full topic map and `audit` prefix rules. Always state the routing decision in one line before dispatching. Each agent prompt must be self-contained (target paths, original ask, expected report shape).

---

## Critical gotchas

- **Web vs mobile branches everywhere.** `kIsWeb` guard required for: `path_provider`, `dart:io File`, `firebase_crashlytics`, `flutter_pdf_text`, `flutter_pdfview`, `tesseract_ocr`. `local://` book links rejected on web.
- **OCR datasource is conditional-import only.** `lib/features/library/data/ocr_data_source.dart` selects `_io.dart` or `_web.dart` via `dart.library.js_interop`. Never import `_io.dart` or `_web.dart` directly — go through `OcrDataSource` / `createOcrDataSource()`.
- **OCR assets must be present at build time.** Mobile expects `assets/tessdata/{eng,tha}.traineddata`; web expects `web/ocr/tesseract.min.js`, `web/ocr/worker.min.js`, `web/ocr/tesseract-core-simd.wasm`, and `web/ocr/lang/{eng,tha}.traineddata.gz`. See README for download URLs. Folders are scaffolded with `.gitkeep` only.
- **Read flags through `featureFlagsProvider`.** Never call `FirebaseRemoteConfig.instance` from app code — go through the provider so test overrides and the singleton lifecycle stay intact.
- **Hive `app_prefs` writes only via dedicated services.** `RecentBooksService` owns `recent_book_ids`; `OcrCacheService` owns `ocr_v1_*`. New keys require a new service in `lib/core/local/`.
- **TTS on Android 11+** needs `<intent action android.intent.action.TTS_SERVICE>` inside `<queries>` in `AndroidManifest.xml` (package visibility).
- **Web TTS voices** populate async — `_trySetWebVoice` polls `getVoices()` and retries on first user gesture.
- **Firestore `whereIn` cap is 30** — `watchUserNotesCount` chunks `bookIds` and merges streams.
- **Theme tokens only** — use `AppColors` / `AppTypography`, never raw hex/font names.
- **Routes only via `GoRouter`** — no `Navigator.push`. `/book/:id/lock` is the per-book PIN gate; redirect logic lives in `routerProvider`.
- **`firebase_options.dart`** is generated by `flutterfire configure`. Do not hand-edit.
- **Edge Function URL** lives as `kCorsProxyBase` constant in `lib/core/network/pdf_fetcher.dart`. Update after redeploy.
- **No avatar field** on user profile — name + email only.
- **Biometric sign-in is removed.** `local_auth` and `BiometricAuthService` survive ONLY because the per-book lock uses them. Don't reintroduce a profile-level biometric toggle.

### Pre-existing security debts (deliberately deferred for demo scope)
- `web/index.html` loads pdf.js from `cdnjs.cloudflare.com` without SRI.
- No CSP / COEP / COOP headers on the web build (Tesseract.js SIMD WASM degrades silently without `Cross-Origin-Embedder-Policy: require-corp`).
- Hive `app_prefs` cache is unencrypted.
- `tesseract_ocr 0.5.0` upstream has been unmaintained since 2023.

---

## DO NOT

- **Never** import `flutter/`, `firebase_*`, or `supabase_*` packages inside any `domain/` layer — domain stays plain Dart.
- **Never** use `setState` for app/shared state — Riverpod providers only. UI-local ephemeral state (form focus, animation tickers) is the only exception.
- **Never** hardcode colors, font families, or text sizes — use `AppColors` / `AppTypography` only.
- **Never** call `http.get` directly for PDF bytes — go through `fetchPdfBytes` in `lib/core/network/pdf_fetcher.dart` so the web CORS proxy is honored.
- **Never** use `Navigator.push` / `Navigator.pop` for navigation — GoRouter only (`context.go` / `context.push` / route constants in `app_routes.dart`).
- **Never** hand-edit `lib/firebase_options.dart` — regenerate via `flutterfire configure`.
- **Never** use `flutter_pdfview` on web — it's mobile-only. Web reader must use `pdfx` + cached bytes.
- **Never** store or accept `local://` book links on web — reject in `pdfPathProvider`. Mobile-legacy only.
- **Never** add Firebase Storage — all PDFs go to Supabase bucket `pdfs`.
- **Never** call `path_provider` or `dart:io File` without a `kIsWeb` guard.
- **Never** import `flutter_pdf_text` on web — use Syncfusion bytes for web TTS text.
- **Never** add an avatar field or any profile column beyond `name` + `email`.
- **Never** call `FirebaseRemoteConfig.instance` directly — read flags through `featureFlagsProvider` so test overrides and the initialized singleton lifecycle hold.
- **Never** write to the Hive `app_prefs` box outside the dedicated services (`RecentBooksService`, `OcrCacheService`). New keys need a new service.
- **Never** import `tesseract_ocr` from web code — it's mobile/FFI only. Web OCR goes through the conditional `_web.dart` impl behind `OcrDataSource`.
- **Never** import `ocr_data_source_io.dart` or `ocr_data_source_web.dart` directly — depend only on `OcrDataSource` + `createOcrDataSource()` so the conditional import resolves the right impl per platform.
- **Never** reintroduce a profile-level biometric sign-in toggle — biometric stays scoped to the per-book lock.

---

## Working rules (mandatory)

**Assumptions explicit.** If context missing, state the assumption before acting. Don't hallucinate hidden infra or invent unspecified services.

**Evidence before assertions.** Never claim a change is complete without running verification. "I edited the file" is not done — "I edited the file and here's the `flutter analyze` / `flutter test` output" is done. No "should work now."

**Surface concerns before major change:**
- Blast radius if this goes wrong?
- What assumptions are we making?
- Reversibility path?
- What are we NOT seeing because of momentum?

**Track scope drift.** Flag when:
- "Just one more thing" accumulates
- Nice-to-haves get treated as must-haves
- Ask was "fix bug X" but we're now "refactoring the entire module"

**Reversibility tiers:**
- **R0 (irreversible)** — STOP. Ask before proceeding. (force-push, dropping data, deleting branches, deploying to prod, deleting Supabase objects, dropping Firestore docs in bulk)
- **R1 (costly to reverse)** — Do it, but say why first. (schema migrations, rule changes, dependency upgrades, hand-edits to generated files)
- **R2 (easily reversed)** — Just do it. (local file edits, new tests, refactors with green tests, stage/unstage)

---

## Quality gates (must pass before merge)

| Gate | Requirement |
|---|---|
| **Correctness** | `flutter analyze` clean (zero warnings/errors) · `flutter test` green (current baseline: 181 pass · 2 skipped · 0 fail) · domain layer (`lib/features/*/domain/`) >80% line coverage |
| **Security** | No secrets committed (Supabase anon key in `main.dart` is public-by-design; service keys never in repo) · Firestore rules + Supabase RLS reviewed for any new collection/bucket path · auth state checked on every protected route |
| **Accessibility** | `Semantics` labels on every interactive widget (buttons, list items, icon-only taps) · WCAG AA contrast on `AppColors` pairings · tap targets ≥48×48 dp |
| **Performance** | No unbounded `ListView` (use `.builder` + key) · all images and thumbnails cached · streams disposed in `ref.onDispose` · no synchronous PDF byte work on the UI isolate for files >2 MB |

Coverage check: `flutter test --coverage && genhtml coverage/lcov.info -o coverage/html` (lcov optional, `--coverage` produces `lcov.info`).

---

## Configuration touch-points

- `lib/main.dart` — Supabase URL + anon key, Hive box open, Firebase + Crashlytics init, `FeatureFlags` initialize + `featureFlagsProvider` override
- `lib/firebase_options.dart` — Firebase config (generated)
- `lib/core/config/feature_flags.dart` — Remote Config defaults (`_defaults` map) + typed getters
- `lib/core/network/pdf_fetcher.dart` — Edge Function URL
- `android/app/src/main/AndroidManifest.xml` — TTS_SERVICE intent query, `USE_BIOMETRIC` permission
- `supabase/functions/pdf-proxy/index.ts` — Deno CORS proxy source
- `assets/tessdata/` (mobile) and `web/ocr/` (web) — OCR engine assets, populated manually per README
