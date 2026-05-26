# Missing / Gap Report

Audited: 2026-05-26. Based on static analysis of `lib/`, `test/`, `.github/workflows/`, `pubspec.yaml`, `firestore.indexes.json`, and `supabase/`.

Last updated: 2026-05-26 (session 5 — dart format, CI hardening fixes, ocr_pipeline load fix).

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

## ✅ Also resolved this session

### R2 — Riverpod codegen (@riverpod + build_runner) → DONE
Added `riverpod_annotation: ^2.6.1` (dep) + `riverpod_generator: ^2.6.4` + `build_runner: ^2.4.15` (dev deps). Migrated all 30+ providers across 8 files to `@riverpod` / `@Riverpod(keepAlive: true)` annotations:
- `StateNotifier` controllers → `Notifier` (auth, library, app PIN session, karaoke)
- `Provider` / `StreamProvider` / `FutureProvider` / `StateProvider` → annotated functions/classes
- `BookOcrProgress` (`StateProvider`) → `@riverpod class` with explicit `set()` method; 4 call sites in `reading_screen.dart` updated
- `dart run build_runner build --delete-conflicting-outputs` generates 8 `.g.dart` files
- `flutter analyze` clean · `flutter test` 200 pass / 1 pre-existing skip

---

## ✅ Also resolved this session (session 3)

### R5 — Cross-platform integration tests in CI → DONE
Added two new CI jobs to `.github/workflows/ci.yml`:
- `integration-android` (`runs-on: macos-latest`, `reactivecircus/android-emulator-runner@v2`, API 33 x86_64) — runs `flutter test integration_test/` on every PR.
- `integration-web` (`runs-on: ubuntu-latest`, `flutter test --platform chrome integration_test/app_test.dart`) — runs on every PR. (Originally `flutter drive`; corrected in session 5 — see CI fixes below.)
Both jobs are gated to `pull_request` events to keep push CI lean.
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
- `google/osv-scanner-action`: v2.x is a reusable workflow, not a composite action. Fixed from step-level `uses:` to job-level `uses: .../.github/workflows/osv-scanner-reusable.yml@v2.3.8`. Neither `@v1` nor `@v2` are valid tags — only full semver (e.g. `v2.3.8`).
- `integration-web`: replaced `flutter drive` (required separate ChromeDriver process) with `flutter test --platform chrome`; Google Chrome is pre-installed on `ubuntu-latest` runners.

### ocr_pipeline_test.dart load failure → FIXED
`test/features/library/presentation/ocr_pipeline_test.dart` had no `void main() {}` entry point. The test runner attempted to load the file before evaluating `--exclude-tags=ocr-pipeline`, hit a missing-entrypoint error, and reported a hard `-1` failure. Added `void main() {}` — file now loads and skips cleanly.

**New test baseline: 250 pass / 2 skip / 0 fail** (was 250 / 1 / 1).

---

## Hard misses

### R4 — Firestore offline persistence + offline-first cache
No `Settings(persistenceEnabled: true)`, `setPersistenceEnabled`, or `enablePersistence` call anywhere. The app is purely online-only — books, shelves, and notes fail silently when offline.

**What's needed:** enable Firestore persistence in `main.dart` before `runApp`. Consider an offline-first repository layer (serve cache → sync on reconnect).

---

### R5 — Dynamic type (MediaQuery.textScaler)
Zero occurrences of `textScaler` or `textScaleFactor` in `lib/`. Font sizes are hardcoded through `AppTypography` with no respect for the OS accessibility text-size setting.

**What's needed:** wrap text-size-sensitive widgets with `MediaQuery.textScalerOf(context)` scaling, and add a widget test that pumps under a non-1.0 text scale factor.

*Note: WCAG AA contrast documentation is present and complete in `docs/accessibility.md` — that half of the R5 claim is already satisfied.*

---

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
