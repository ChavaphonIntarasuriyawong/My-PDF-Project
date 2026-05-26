# Missing / Gap Report

Audited: 2026-05-26. Based on static analysis of `lib/`, `test/`, `.github/workflows/`, `pubspec.yaml`, `firestore.indexes.json`, and `supabase/`.

Last updated: 2026-05-26 (session 8 — R5 textScaler fixed-height containers resolved).

---

## ✅ Done and verified in code

### App-level PIN gate (biometric session resume)
- `lib/core/local/app_pin_service.dart` — Hive-backed, SHA-256 hash; `appPinServiceProvider` exposed for test override.
- `lib/core/local/app_pin_session.dart` — `appPinSessionProvider` (`StateNotifier<bool>`) tracks PIN-entered state per session.
- `lib/features/auth/presentation/pin_setup_screen.dart` — shown once after registration.
- `lib/features/auth/presentation/pin_entry_screen.dart` — shown on every cold start / resume; biometric quick-unlock via `BiometricAuthService`.
- GoRouter redirect covers all states: loading, logged-out, PIN-not-set, PIN-not-entered, content.

### Firestore offline persistence (R4)
`lib/main.dart:36-39` — `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)` set immediately after `Firebase.initializeApp()`, before any Firestore reads or writes.

- Mobile: SQLite-backed local cache via the Firestore SDK.
- Web: IndexedDB via the same `Settings` API (`cacheSizeBytes` web-ignored).
- Books, shelves, and notes load from local cache while offline; sync on reconnect.

### CI pipeline (4 jobs, all passing)

| Job | Trigger | Mechanism |
|---|---|---|
| `flutter-ci` | push + PR | `dart format --set-exit-if-changed` → `flutter analyze --fatal-infos` → `flutter test --exclude-tags=golden,ocr-pipeline` |
| `secret-scan` | push + PR | `gitleaks/gitleaks-action@v2` with `fetch-depth: 0` |
| `osv-scan` | push + PR | `google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@v2.3.8` (job-level reusable workflow; `security-events: write` granted) |
| `integration-web` | PR only | `flutter drive --driver test_driver/integration_test.dart --target integration_test/app_test.dart -d web-server --browser-name=chrome --headless` (ChromeDriver pre-installed on `ubuntu-latest`) |

Flutter pinned to `3.44.0`. Android emulator job removed — GitHub Actions macOS runners have an unfixable `adb: device not found` race condition.

### Test suite

**Baseline: 250 pass / 1 skip / 0 fail**

| Test file | What it covers |
|---|---|
| `test/screens/pin_setup_screen_test.dart` | `PinSetupScreen` — 6 tests: rendering, 6-digit entry, mismatch, success→home |
| `test/screens/pin_entry_screen_test.dart` | `PinEntryScreen` — 6 tests: rendering, wrong PIN, cooldown, forgot-PIN sign-out |
| `test/screens/note_edit_screen_test.dart` | `NoteEditSheet` — 8 tests: create mode, edit mode, validation |
| `test/features/auth/domain/auth_failure_test.dart` | `Failure` hierarchy, const-constructibility, `message` field — 8 tests |
| `test/features/auth/domain/auth_repository_test.dart` | `Either<Failure,T>` contracts for login / register / logout / authStateChanges — 9 tests |
| `test/accessibility/text_scale_test.dart` | `LoginScreen` renders without overflow at 1.0×, 1.5×, 2.0×; verifies `MediaQuery.textScaler` propagates correctly |
| `integration_test/app_test.dart` | Unauthenticated launch, field input, empty-submit snackbar, PhoneFrame smoke |

The 1 skip is `test/features/library/presentation/ocr_pipeline_test.dart` (`@Tags(['ocr-pipeline'])` + `@Skip`; excluded by `--exclude-tags=ocr-pipeline`; file has `void main() {}` so it loads cleanly).

---

## Hard misses

### R2 — Riverpod codegen (@riverpod + build_runner)

`riverpod_annotation` and `riverpod_generator` are in `pubspec.yaml` but **codegen was never run or committed**. There are zero `@riverpod` annotations and zero `.g.dart` files anywhere in `lib/`. All providers still use the traditional Riverpod API (`Provider`, `StreamProvider`, `StateNotifierProvider`, etc.).

**What's needed:** annotate providers with `@riverpod` / `@Riverpod(keepAlive: true)`, run `dart run build_runner build --delete-conflicting-outputs`, commit the 8 generated `.g.dart` files, and update CI to run `build_runner` before `flutter analyze`.

---

### ✅ R5 — Dynamic type (MediaQuery.textScaler) → DONE (session 8)

Fixed 5 files where `SizedBox(height: N)` prevented widgets from growing at large OS text scale factors (1.5×, 2.0×):

| File | Fix |
|---|---|
| `lib/shared/widgets/gradient_button.dart` | `SizedBox(h:56)` → `ConstrainedBox(minHeight:56)` |
| `lib/shared/widgets/app_modal.dart` | Cancel + Destructive buttons: `SizedBox(h:52)` removed, `minimumSize` moved into `styleFrom` |
| `lib/features/auth/presentation/widgets/pin_widgets.dart` | Digit/backspace keys `SizedBox(h:64)` → `ConstrainedBox(minHeight:64)`; biometric `SizedBox(h:48)` removed (redundant with `minimumSize`); `PinStatusLine` placeholder height scaled via `MediaQuery.textScalerOf` |
| `lib/features/library/presentation/book_lock_screen.dart` | Same 4 patterns as `pin_widgets` |
| `lib/features/reader/presentation/widgets/karaoke_text_pane.dart` | `SizedBox(w:32)` removed from speed label |

`test/accessibility/text_scale_test.dart` passes. **250 pass / 1 skip / 0 fail.**

---

## Confirmed partial gap

### Supabase RLS not in source control

`supabase/` contains only `functions/`. No `migrations/` directory, no `.sql` files with `CREATE POLICY` / `ENABLE ROW LEVEL SECURITY`. RLS is configured on the Supabase dashboard only — unverifiable and unreviewable from source control.

**What's needed:** export RLS policies to `supabase/migrations/` so they are reviewed and version-controlled alongside the app.

---

## Claims that did not hold up

| Claim | Verdict |
|---|---|
| R2 Riverpod codegen → DONE (prior MISSING.md) | **Wrong** — no `@riverpod` annotations and no `.g.dart` files exist in `lib/`. `riverpod_generator` is in dev deps but codegen was never run. |
| Library domain "1/3 models tested" | **Wrong** — `book_model_test.dart`, `bookshelf_model_test.dart`, and `note_model_test.dart` all exist. |
| Notes Firestore index over-specified | **Not reproduced** — `(bookId ASC, createdAt DESC)` matches the `watchNotes` query exactly. |
| Font sizes ignore OS text-scale setting | **Resolved** — fixed-height containers converted to `minHeight` constraints (session 8); `PinStatusLine`/`_StatusLine` placeholder height now scaled via `MediaQuery.textScalerOf`. |
