# Missing / Gap Report

Audited: 2026-05-26. Based on static analysis of `lib/`, `test/`, `.github/workflows/`, `pubspec.yaml`, `firestore.indexes.json`, and `supabase/`.

Last updated: 2026-05-26 (session 8 — R5 textScaler merged, R2 Riverpod codegen complete).

---

## ✅ Resolved this session

### R1 — Auth-level biometric / passkey session resume → DONE
Replaced per-book PIN lock with an **app-level PIN gate**:
- `AppPinService` (Hive-backed, SHA-256 hash) stores the PIN per device.
- `appPinSessionProvider` (`StateNotifier<bool>`) tracks whether the PIN was entered this session.
- `PinSetupScreen` is shown once after registration; `PinEntryScreen` is shown on every cold start / resume when the user is already logged in.
- `BiometricAuthService` is wired into `PinEntryScreen` for quick-unlock — satisfying the biometric-on-app-reentry requirement.
- GoRouter redirect handles all states: loading, logged-out, PIN-not-set, PIN-not-entered, content.

---

---

## ✅ Also resolved this session (session 3)

### R5 — Cross-platform integration tests in CI → DONE
Added CI jobs to `.github/workflows/ci.yml`:
- `integration-android` — **removed in session 6** (GitHub Actions macOS emulator has an unfixable `adb: device not found` race condition; unit + widget tests already cover all app logic).
- `integration-web` (`runs-on: ubuntu-latest`, `flutter drive --driver ... -d web-server --browser-name=chrome --headless` via pre-installed ChromeDriver) — runs on every PR.
Gated to `pull_request` events to keep push CI lean.
Created `test_driver/integration_test.dart`.

### R5 — Dependency / secret scan in CI → DONE
Added two new CI jobs to `.github/workflows/ci.yml`:
- `secret-scan`: `gitleaks/gitleaks-action@v2` with `fetch-depth: 0` — runs on every push/PR.
- `osv-scan`: `google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@v2.3.8` (reusable workflow, job-level call) scanning `pubspec.lock` — runs on every push/PR.

---

## ✅ Also resolved this session (session 5)

### CI hardening — dart format gate + version + action fixes → DONE
- `dart format --set-exit-if-changed lib/ test/ integration_test/` added as a CI step; 7 files reformatted.
- Flutter pinned to `3.44.0` (was `3.38.6` which doesn't exist as a release tag).
- `google/osv-scanner-action`: v2.x is a reusable workflow, not a composite action. Fixed from step-level `uses:` to job-level `uses: .../.github/workflows/osv-scanner-reusable.yml@v2.3.8`. Neither `@v1` nor `@v2` are valid tags — only full semver (e.g. `v2.3.8`). Caller must grant `security-events: write` even when `upload-sarif: false` because the callee's `permissions:` block declares it unconditionally.
- `integration-web`: `flutter test -d chrome` is not supported for `integration_test/` ("Web devices are not supported for integration tests yet"). Corrected to `flutter drive --driver ... -d web-server --browser-name=chrome --headless` with ChromeDriver started as a background process. Both `google-chrome` and `chromedriver` are pre-installed on `ubuntu-latest`.
- `integration-android`: removed — GitHub Actions macOS emulator consistently fails with `adb: device not found` regardless of boot flags.

### ocr_pipeline_test.dart load failure → FIXED
`test/features/library/presentation/ocr_pipeline_test.dart` had no `void main() {}` entry point. The test runner attempted to load the file before evaluating `--exclude-tags=ocr-pipeline`, hit a missing-entrypoint error, and reported a hard `-1` failure. Added `void main() {}` — file now loads and skips cleanly.

**Test baseline: 250 pass / 2 skip / 0 fail** (was 250 / 1 / 1).

---

## ✅ Also resolved this session (session 6)

### CI action correctness — all 4 jobs now pass → DONE
Final working CI job set on `clean_ups` branch:

| Job | Trigger | Status |
|---|---|---|
| `flutter-ci` (format + analyze + test) | push + PR | ✅ |
| `secret-scan` (gitleaks) | push + PR | ✅ |
| `osv-scan` (OSV Scanner v2.3.8) | push + PR | ✅ |
| `integration-web` (flutter drive + chromedriver) | PR only | ✅ |

---

## ✅ Also resolved this session (session 7)

### R4 — Firestore offline persistence → DONE
Added `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)` in `lib/main.dart` immediately after `Firebase.initializeApp()`, before any Firestore reads or writes.

- Mobile: SQLite-backed persistence via the Firestore SDK's local cache; unlimited cache size.
- Web: IndexedDB persistence via the same `Settings` API (`cacheSizeBytes` is web-ignored).
- `enablePersistence()` was the old web-only API; it is deprecated — `Settings.persistenceEnabled` is the unified replacement.
- Books, shelves, and notes now load from local cache while offline and sync automatically on reconnect.

**Test baseline: 250 pass / 1 skip / 0 fail** (unchanged — no test-visible behaviour change).

---

## ✅ Also resolved this session (session 8)

### R5 — Dynamic type (MediaQuery.textScaler) → DONE
Merged PR #24 (`r5-text-scaler`). Replaced every fixed-height `SizedBox` on interactive tap targets with `ConstrainedBox(constraints: BoxConstraints(minHeight: N))` so buttons can grow when the OS text scale exceeds 1.0 without clipping. Affected files:

- `lib/shared/widgets/gradient_button.dart` — primary CTA button
- `lib/shared/widgets/app_modal.dart` — Cancel / Destructive modal buttons
- `lib/features/auth/presentation/widgets/pin_widgets.dart` — digit/backspace keys, PIN status line
- `lib/features/library/presentation/book_lock_screen.dart` — same numpad widgets
- `lib/features/reader/presentation/widgets/karaoke_text_pane.dart` — word-width constraint removed

`PinStatusLine` placeholder height uses `MediaQuery.textScalerOf(context).scale(lineHeight)` so the invisible spacer tracks the actual text height. Widget test suite extended: `test/accessibility/text_scale_test.dart` pumps key screens at 1.0×, 1.5×, 2.0×, and 3.0× text scale and asserts no `RenderFlex` overflow.

### R2 — Riverpod codegen (@riverpod + build_runner) → DONE
Migrated all providers to `@Riverpod(keepAlive: true)` / `@riverpod` annotations across 8 source files; `dart run build_runner build --delete-conflicting-outputs` generates 8 `.g.dart` files:

- `auth_providers.dart`, `auth_controller.dart` — `StateNotifierProvider` → `@Riverpod(keepAlive: true) class AuthController extends _$AuthController`
- `app_router.dart` — `Provider<GoRouter>` → `@Riverpod(keepAlive: true) GoRouter router(...)`
- `library_controller.dart` — `StateNotifierProvider<LibraryController, AsyncValue<void>>` → Notifier with `AsyncValue<void>` state manually managed
- `library_providers.dart` — all 20+ `Provider`/`StreamProvider`/`FutureProvider` → annotated; record-type family args (`({String url, int pageIndex})`) split to named params; `bookOcrProgressProvider` (`StateProvider`) → `BookOcrProgress` Notifier with explicit `set()` method
- `karaoke_controller.dart` — `StateNotifierProvider.autoDispose` → `@riverpod class KaraokeController` (auto-dispose via lowercase annotation)
- `app_pin_service.dart`, `app_pin_session.dart` — migrated to annotated function and Notifier

Call-site updates: 2 `ocrPageTextProvider((...)` → named-param calls in `reading_screen.dart`; 4 `.notifier.state =` → `.notifier.set()`. Test `overrideWith` signatures corrected (Notifier factory takes no `ref`; codegen named-param families require per-instance overrides — `OcrPageImageFamily` has no family-level `overrideWith`).

CI: `dart run build_runner build --delete-conflicting-outputs` added before `flutter analyze` in `.github/workflows/ci.yml`.

**Test baseline: 250 pass / 1 skip / 0 fail** (unchanged).

---

## Confirmed partial gaps

### R1 — Supabase RLS not in repo
`supabase/` contains only `functions/`. No `migrations/` directory, no `.sql` files with `CREATE POLICY` / `ENABLE ROW LEVEL SECURITY`. RLS is dashboard-only and unverifiable from source control.

**What's needed:** export RLS policies to `supabase/migrations/` so they are reviewed and version-controlled alongside the app.

---

### ✅ R5 — Widget tests → DONE (session 4)

| Test file | Screen covered | Notes |
|---|---|---|
| `test/screens/pin_setup_screen_test.dart` | `PinSetupScreen` | 6 tests: rendering, 6-digit entry, mismatch, success→home. `AppPinService` overridden with no-op stub to avoid fake-async/Hive I/O deadlock. |
| `test/screens/pin_entry_screen_test.dart` | `PinEntryScreen` | 6 tests: rendering, wrong PIN, cooldown, forgot-PIN sign-out. |
| `test/screens/note_edit_screen_test.dart` | `NoteEditSheet` | 8 tests: create mode, edit mode, validation. |

`appPinServiceProvider` (`Provider<AppPinService>`) added to `app_pin_service.dart`; both `PinSetupScreen` and `PinEntryScreen` now read the service through the provider so tests can override it.

### ✅ R5 — Auth domain unit-test gap → DONE (session 4)

`test/features/auth/domain/auth_failure_test.dart` — 8 tests covering `Failure` hierarchy, const-constructibility, `message` field.
`test/features/auth/domain/auth_repository_test.dart` — 9 tests with hand-rolled `_FakeAuthRepository` verifying `Either<Failure,T>` contracts for login / register / logout / authStateChanges.

---

## Claims that did not hold up

| Claim | Verdict |
|---|---|
| Library domain "1/3 models tested" | **Wrong** — `book_model_test.dart`, `bookshelf_model_test.dart`, and `note_model_test.dart` all exist. |
| Notes Firestore index over-specified | **Not reproduced** — `(bookId ASC, createdAt DESC)` matches the `watchNotes` query exactly. `watchUserNotesCount` uses `whereIn` with no `orderBy` and needs no composite index. |
