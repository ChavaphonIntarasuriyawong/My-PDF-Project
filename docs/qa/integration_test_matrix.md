# Integration Test Matrix — Wave 3 (branch `A`)

Manual + automated coverage map for the enterprise gap-closure deliverable
"integration tests for Android + Web". Automated harness lives at
`integration_test/app_test.dart`; full E2E with real Firebase + Supabase is
**deferred to manual QA in Wave 4** because CI runners do not have project
service-account credentials provisioned.

## Run commands

| Target | Command |
|---|---|
| Android emulator | `flutter test integration_test/` |
| Web (Chrome) | `flutter drive --driver test_driver/integration_test.dart --target integration_test/app_test.dart -d chrome` |
| All tests (host) | `flutter test` |
| Goldens (regen) | `flutter test --update-goldens test/golden/` |
| Goldens (verify) | `flutter test test/golden/` |

A `test_driver/integration_test.dart` driver file is required for the web run.
If absent, create with:

```dart
import 'package:integration_test/integration_test_driver.dart';
Future<void> main() => integrationDriver();
```

## Scenario × Platform matrix

| # | Scenario | Android | Web | Automated | Manual |
|---|---|---|---|---|---|
| 1 | App launches, lands on `/login` when unauthenticated | PASS (auto) | PASS (auto) | yes | n/a |
| 2 | Email + password fields accept text input | PASS (auto) | PASS (auto) | yes | n/a |
| 3 | Empty submit shows validation snackbar | PASS (auto) | PASS (auto) | yes | n/a |
| 4 | PhoneFrame applies on web ≥600 px viewport | n/a | DEFERRED | partial | Wave 4 |
| 5 | Successful login navigates to `/home` | DEFERRED | DEFERRED | no | Wave 4 (real account) |
| 6 | Add book by URL → reader opens → progress saved | DEFERRED | DEFERRED | no | Wave 4 |
| 7 | TTS plays on mobile / web | DEFERRED | DEFERRED | no | Wave 4 |
| 8 | OCR fallback triggers on scanned PDF | DEFERRED | DEFERRED | no | Wave 4 |
| 9 | Logout clears recents + returns to `/login` | DEFERRED | DEFERRED | no | Wave 4 |
| 10 | Biometric enroll prompt after login | partial (widget test) | n/a (web no-op) | unit | Wave 4 device |

`PASS (auto)` rows are exercised by `integration_test/app_test.dart`.
`DEFERRED` rows require live backend or a hardware feature unavailable in the
host CI; tracked for Wave 4 manual evidence collection.

## Wave 4 manual checklist (open issues)

- Provision a dedicated `qa-test@mypdf.dev` Firebase Auth user with seeded
  shelves + books for repeatable manual runs.
- Capture screenshots of scenarios 5–9 on Android emulator + Chrome and stash
  them under `docs/evidence/screenshots/`.
- Record a short screen capture of biometric enroll on a real device
  (emulator with fingerprint enrolled is acceptable).
- Confirm scenario 4 by resizing Chrome to 1024×768 and observing the
  centered 412×896 phone frame; on a 360×640 emulated mobile viewport, the
  frame must collapse to pass-through.

## Component-level golden coverage

`test/golden/` ships:

- `login_screen.png` — full LoginScreen, logged-out.
- `home_empty.png` — HomeScreen with zero books.
- `profile.png` — ProfileScreen with stub user.
- `gradient_button_idle.png`, `gradient_button_loading.png`,
  `gradient_button_disabled.png` — primary CTA across all states.
- `status_badge_states.png` — badge for `reading` / `finished` / `on_hold`.

Component-level goldens act as the rebound surface if full-screen goldens
drift across CI runners due to font fallback differences. Regenerate with
`flutter test --update-goldens test/golden/`.
