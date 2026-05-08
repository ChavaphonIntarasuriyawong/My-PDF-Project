# Enterprise Assignment Gap Closure (branch `A`)

## Context

Term assignment requires enterprise-grade Flutter app with: committed Firestore rules, biometric auth fallback, integration + golden tests, CI/CD, structured logging, audit report, evidence package, RBAC, accessibility sweep.

Audit ran on `forfun` (richer baseline) but most gaps apply equally to `A`. `A` has OCR feature only — fewer screens to test = some gaps cheaper to close here. User picked `A` because `forfun` features (karaoke/achievement/streak) may not stay.

R-tier overall: **R1** — multiple new files + dep additions + new firestore.rules (production-affecting). Reversible by branch revert.

## Audit gaps (from forfun audit, applicable to A)

**GAP (9 — must close):**
1. Firestore rules — no `firestore.rules` in repo (console-managed).
2. Biometric/Passkey fallback — no `local_auth`.
3. Integration tests — no `integration_test/` dir.
4. Golden tests — none.
5. CI/CD — no `.github/workflows/`.
6. Plan files not committed in `.claude/plans/`.
7. Structured logging — only `debugPrint`.
8. Audit report (D2) — not written.
9. Evidence package (D4) — no screenshots dir.

**PARTIAL (6 — strengthen):**
10. Supabase anon key in `main.dart` — document as public-by-design.
11. Riverpod codegen — manual providers OK per assignment (says "OR BLoC"). Document choice in audit report.
12. Composite indexes — schema documented, indexes not.
13. Rollback plan — partial in QA matrix. Need formal section in audit report.
14. Domain coverage % — run `flutter test --coverage`, document in audit report.
15. Semantics labels — only 4 files. Need full sweep.

## Approach (5 waves, ~5 sprints if solo, faster with team)

### Wave 1 — Foundation (R2, quick wins)
Owner agent: `flutter_engineer` + `qa_engineer` parallel.

- **Commit `.claude/plans/`** to repo. Add `ok-start-plan-first-eager-mountain.md` + future plans. Update `.gitignore` to allow.
- **Structured logging** — add `logger: ^2.4.0` (or similar). Replace `debugPrint` site-by-site (or wrap). Write a `lib/core/logging/app_logger.dart` with severity levels + Crashlytics breadcrumb integration.
- **CI/CD** — `.github/workflows/ci.yml` with jobs: format check, `flutter analyze`, `flutter test --coverage`, build APK (Android) + web. Coverage upload optional.
- **Coverage gate** — run `flutter test --coverage`, document baseline %, target >80% domain.

Verification: `flutter analyze` clean · CI green on PR · logger appears in Crashlytics breadcrumbs.

### Wave 2 — Security (R1)
Owner agent: `firebase_specialist` + `security` parallel.

- **`firestore.rules`** committed at repo root. Rules must use:
  - `request.auth != null` for all access.
  - `request.auth.uid == resource.data.ownerId` for owner checks.
  - `diff().affectedKeys()` whitelisting on book/note updates (only mutable fields).
  - `request.time` validation on `lastReadAt`, `createdAt` (server timestamp ≤ now + grace).
  - RBAC: `users/{uid}.role` field (default `'user'`, optional `'admin'`). Admin can read all books for the mock dashboard.
- **Add `users.role` field** to UserModel (domain), datasource, fromMap/toMap. Default `'user'`. Migrate existing docs lazy-on-read.
- **Biometric fallback** — add `local_auth: ^2.3.0`. New file `lib/features/auth/data/biometric_auth_service.dart`. Wrap login screen post-credential-success with optional biometric enroll. On subsequent app open, offer biometric → resume session via secure flag in Hive `app_prefs` (key: `biometric_enabled`).
- **firebase.json** — wire `firestore.rules` path so `firebase deploy --only firestore:rules` works.

Verification: `firebase emulators:start --only firestore` + rule unit tests via `@firebase/rules-unit-testing` (or manual test matrix). Biometric flow works on Android device or emulator with fingerprint enrolled.

### Wave 3 — Quality Gates (R5)
Owner agent: `qa_engineer` + `flutter_engineer` parallel.

- **Integration tests** — `integration_test/` dir. Cover golden path: launch → login → home → add book by URL → open reader → tap Read (TTS) → trigger OCR fallback → back → logout. Run on Android (`flutter test integration_test/`) and Web (`flutter drive --driver test_driver/integration_test.dart --target integration_test/app_test.dart -d chrome`).
- **Golden tests** — at minimum: LoginScreen, HomeScreen, ReadingScreen empty-state, ProfileScreen. Use `matchesGoldenFile()`. Generate goldens with `flutter test --update-goldens`.
- **Semantics sweep** — every interactive widget gets a `Semantics` label. Buttons, list tiles, icon-only taps, tap-targets ≥48×48 dp. Audit existing screens via subagent.
- **Contrast doc** — generate `docs/accessibility.md` mapping `AppColors` foreground/background pairs to WCAG AA contrast ratios (use a contrast-ratio calc).
- **Performance sweep** — confirm no unbounded ListView (audit said clean). Document image cache strategy.

Verification: `flutter test` + `flutter test integration_test/` green on Android + Web. Goldens diff zero. Semantics sweep tracked in `docs/accessibility.md`.

### Wave 4 — Documentation (D2 + D4)
Owner agent: `architect` (writes report) + `qa_engineer` (evidence collection).

- **Audit report** — `docs/audit_report.md`, 5-8 pages. Sections required:
  1. Agent workflow — orchestration loop, prompts, context drift handling, handoff between waves.
  2. Architecture & data — domain modeling, Firestore subcollection layout, justification of Riverpod manual (not codegen).
  3. Security matrix — RBAC roles vs permissions table, Firestore rules walkthrough, secret-handling posture (Supabase anon key public-by-design).
  4. Observability & rollback — Crashlytics flow, structured logger sample output, Remote Config rollback recipe (`ocr_fallback_enabled=false` → instant kill).
  5. Quality gates — coverage %, integration test matrix, accessibility findings.
- **Evidence package** — `docs/evidence/` with subdirs:
  - `screenshots/` — Android screen + Web screen per major flow (login, home, reader, OCR triggered).
  - `crashlytics/` — screenshot of dashboard with deliberate test crash logged.
  - `goldens/` — copies of generated goldens.
  - `agent_transcripts/` — copy of plan-mode runs (paste from `.claude/plans/`).
- **Rollback plan formal section** — `docs/rollback_plan.md` covering Remote Config flips, Firestore rules rollback, store binary rollback path.

Verification: report renders in any Markdown viewer. Evidence dir populated. Linked from CLAUDE.md.

### Wave 5 — Polish (PARTIAL → PASS)
Owner agent: `firebase_specialist` + `architect` parallel.

- **Composite Firestore indexes** — `firestore.indexes.json` at repo root. Cover:
  - `books` ordered by `lastReadAt desc` filtered by `ownerId`.
  - `books` filtered by `shelfId` + `ownerId`.
  - `notes` filtered by `bookId` + ordered by `createdAt`.
- **Coverage report** — generate lcov, document % per layer in audit report. Push domain ≥ 80%.
- **Riverpod codegen decision** — document in audit report under Architecture: chose manual providers, justify (smaller dep tree, no `build_runner`).
- **Final CI/CD hardening** — branch protection rule on `main`: require PR + green CI before merge. (Optional, GitHub repo setting, not in code.)

Verification: `firebase deploy --only firestore:indexes` deploys cleanly. Coverage report ≥80% domain.

## Critical files

**New:**
- `firestore.rules`
- `firestore.indexes.json`
- `.github/workflows/ci.yml`
- `lib/core/logging/app_logger.dart`
- `lib/features/auth/data/biometric_auth_service.dart`
- `integration_test/app_test.dart`
- `test/golden/*.dart` (per screen)
- `docs/audit_report.md`
- `docs/accessibility.md`
- `docs/rollback_plan.md`
- `docs/evidence/` (with subdirs)

**Modified:**
- `pubspec.yaml` — add `logger`, `local_auth`.
- `firebase.json` — wire rules + indexes paths.
- `lib/features/auth/domain/user_model.dart` — add `role` field.
- `lib/features/auth/data/firebase_auth_data_source.dart` — read `role` from Firestore.
- `lib/main.dart` — init logger.
- `CLAUDE.md` — link audit report, mark PENDING resolved.
- `.gitignore` — allow `.claude/plans/*.md`.
- All screens with interactive widgets — Semantics sweep.

## Verification (end-to-end)

1. `flutter analyze` clean.
2. `flutter test --coverage` green; domain ≥80%.
3. `flutter test integration_test/` green on Android emulator.
4. `flutter drive ... -d chrome` green on Web.
5. CI workflow green on PR.
6. `firebase deploy --only firestore:rules,firestore:indexes` clean.
7. `firebase emulators` rules tests pass.
8. Manual: login → biometric enroll → app restart → biometric resumes session.
9. Manual: trigger crash via debug button → Crashlytics dashboard receives event.
10. Audit report renders, evidence dir populated, plan files committed.

## Routing for implementation (subagent dispatch per CLAUDE.md)

| Wave | Owner | Reviewer (read-only) |
|---|---|---|
| 1 Foundation | `flutter_engineer`, `qa_engineer` | `architect` |
| 2 Security | `firebase_specialist`, `security` | `architect` |
| 3 Quality | `qa_engineer`, `flutter_engineer` | `security` (a11y check), `architect` |
| 4 Docs | `architect` (writes), `qa_engineer` (evidence) | `security` (rollback review) |
| 5 Polish | `firebase_specialist`, `architect` | `qa_engineer` |

Per CLAUDE.md: writer ≠ approver. Each wave's output reviewed by a different agent before next wave.

## Sprint-level scope guidance

- Tight deadline: Wave 1 + 2 + 4 minimum (CI, rules, biometric, audit report). Skip golden tests + coverage push.
- Loose deadline: all 5 waves. ~2-3 weeks solo, 1-2 weeks with 3-person team parallelizing.
