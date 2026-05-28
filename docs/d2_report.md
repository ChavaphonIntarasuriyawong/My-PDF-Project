# D2 — Enterprise Audit & Orchestration Report

**Project:** MyPDF  
**Platform:** Flutter — Android (primary), Web (secondary)  
**Backend:** Firebase Auth + Cloud Firestore · Supabase Storage + Edge Functions  
**Date:** 28 May 2026  
**Prepared by:** MyPDF Engineering Team

---

## Executive Summary

This report documents the engineering decisions, architectural patterns, security controls, and observability mechanisms underpinning the MyPDF application. MyPDF is a multi-platform PDF reader that allows authenticated users to save, organise, annotate, and listen to PDF documents. The application is built on Flutter with a clean-architecture feature structure, backed by Firebase for authentication and structured data, and Supabase for PDF storage and web CORS proxying.

The report covers four mandated audit areas: (1) the multi-agent orchestration workflow used to manage AI-assisted development at scale, (2) the domain model design and state management rationale, (3) the role-based access control matrix and Firestore security rules, and (4) the observability infrastructure and rollback strategy for the live OCR feature flag.

---

## Section 1 — Agent Workflow & Multi-Agent Orchestration

### 1.1 The Five-Agent Model

Development of MyPDF is assisted by a five-agent orchestration system defined in `.claude/agents/` and governed by the orchestrator instructions in `docs/projectscope.md`. Each agent is scoped to a single concern; no agent is permitted to edit another agent's domain.

| Agent | Concern | Tools Granted | Edit Scope |
|---|---|---|---|
| `architect` | Layering, provider graph, plugin role boundaries | Read, Glob, Grep, Bash | Diagnose only |
| `flutter_engineer` | UI screens, Riverpod controllers, GoRouter, theme tokens, `kIsWeb` branching | Read, Edit, Write, Glob, Grep, Bash | `lib/features/*/presentation/`, `lib/shared/widgets/`, `lib/core/constants/app_router.dart`, `lib/main.dart` |
| `firebase_specialist` | Firestore queries and schema, Supabase upload, Edge Function source, datasources | Read, Edit, Write, Glob, Grep, Bash | `lib/features/*/data/`, `supabase/functions/`, `firestore.rules` |
| `qa_engineer` | Unit/widget tests, `flutter analyze`, manual flow QA, edge cases | Read, Edit, Write, Glob, Grep, Bash | `test/` directory |
| `security` | Auth flow, Firestore rules, Supabase RLS, CORS proxy, secrets, CVEs, XSS | Read, Glob, Grep, Bash, WebFetch | Diagnose only |

The `architect` and `security` agents are intentionally read-only: they may diagnose violations and produce reports, but they cannot modify source files. Only `flutter_engineer` and `firebase_specialist` hold write access, and each is constrained to its own path namespace.

### 1.2 Dispatch Protocol

All dispatches are parallel. The orchestrator sends a single message containing one Task tool call per required agent; sequential dispatch is never used for independent agents, because it serialises work that can run concurrently.

**Topic-map auto-routing** matches the user's intent against a keyword table in `docs/projectscope.md`:

| User intent | Agents dispatched |
|---|---|
| Add/fix a screen, widget, or route | `flutter_engineer` |
| Fix a Firestore query or Supabase upload | `firebase_specialist` |
| Auth flow or login/PIN change | `firebase_specialist` + `security` |
| Security review, rules, or CVE | `security` |
| Write/fix tests or `flutter analyze` red | `qa_engineer` |
| Layering or clean-architecture concern | `architect` |
| New feature spanning data and UI | `architect` + `flutter_engineer` + `firebase_specialist` |
| Pre-merge / pre-release gate | All five agents |

**Explicit `audit` prefix:** The user may also write `audit` (all five), `audit <agent-names>` (named subset), or `audit <feature>` (all five, scoped to `lib/features/<feature>/`) to override the topic map.

Before any dispatch, the orchestrator states the routing decision in one line — e.g., *"Routing → firebase_specialist + security (auth flow change)."* — so the user can redirect before agents are invoked.

### 1.3 Prompt Structure and Prompts Used

Each agent starts cold: it has no memory of previous turns. To prevent agents from making incorrect assumptions, the orchestrator's dispatch rules require every prompt to be self-contained and include four components:

1. **Target paths** — explicit file paths the agent must read first
2. **Original ask** — the user's unmodified request
3. **CLAUDE.md section** — which section the agent must read (e.g., "read the Plugin Role Map")
4. **Expected report shape** — format the agent should return (e.g., `## Violations`, `## Risks`, `## OK`)

Example (from `docs/projectscope.md`): `audit reader` dispatches all five agents, each receiving a self-contained prompt scoped to `lib/features/reader/` with explicit instructions for what to audit and what to return.

The `architect` agent's output format is enforced in its definition (`architect.md`): it must return `## Violations` (with file:line, rule broken, and suggested fix), `## Risks` (structural smells), and `## OK` (reviewed and clean areas). The `flutter_engineer` agent must run `flutter analyze` after any edit and report errors before claiming completion.

### 1.4 Context Drift Challenges and Mitigations

**Challenge:** Because agents start cold each dispatch, they can drift from the project's established patterns, invent non-existent APIs, or creep outside their scope — particularly on longer tasks.

**Mitigations applied:**

- **Mandatory self-contained prompts with file paths.** Agents are always given exact paths to read before acting, preventing hallucination of file structure.
- **Hard edit-scope boundaries.** Each agent file declares a `What you own` section. The `flutter_engineer`, for instance, is explicitly prohibited from touching `domain/` types or `data/` datasources. These constraints are enforced by instruction, not tooling, so agents that violate them produce changes the orchestrator flags as out-of-scope.
- **Diagnose-only agents.** `architect`, `security`, and `qa_engineer` do not hold write tools for production code. This structural constraint ensures that even if one of these agents drifts, it cannot make changes; it can only produce a report that a human reviews.
- **`CLAUDE.md` as single source of truth.** Every agent is instructed to read `CLAUDE.md` first. The file contains an explicit list of "DO NOT" rules (no `Navigator.push`, no hardcoded colours, no Firebase Storage, no direct `FirebaseRemoteConfig.instance` calls), which agents apply as a checklist against their own output.
- **`flutter analyze` as a gate.** The `flutter_engineer` and `qa_engineer` agents run `flutter analyze` after edits. A red analyzer acts as an objective signal that the agent drifted from valid Dart/Flutter patterns.

### 1.5 Handoff Management

After all dispatched agents return, the orchestrator produces a single consolidated report. Results are grouped by severity — **Critical**, **High**, **Medium**, **Info** — with each finding tagged by the agent that produced it. This prevents findings from different agents being evaluated in isolation and allows the team to prioritise across concerns simultaneously.

**Conflict resolution** follows two tiebreaker rules, also defined in `docs/projectscope.md`:

- Structural disagreements (e.g., whether a dependency direction is valid) are resolved by the `architect` agent's verdict.
- Data-exposure disagreements (e.g., whether a Firestore rule is too permissive) are resolved by the `security` agent's verdict.

---

## Section 2 — Architecture & Data

### 2.1 Clean Architecture Pattern

Every feature in `lib/features/` follows a three-layer structure:

```
lib/features/<feature>/
  data/       — SDK adapters (Firebase, Supabase, Hive, HTTP)
  domain/     — Plain Dart models + repository interfaces
  presentation/ — Riverpod controllers, screens, widgets
```

The **domain layer is framework-free by rule**: zero imports of `flutter/`, `firebase_*`, `supabase_*`, `hive*`, `path_provider`, or `dart:io` are permitted inside any `domain/` directory. This is enforced by the `architect` agent as a hard violation. Repository interfaces in `domain/` declare return types as `Either<Failure, T>` from the `dartz` package, using `lib/core/errors/failures.dart` for the failure hierarchy (`AuthFailure`, `ServerFailure`). Datasources in `data/` map SDK exceptions to these failure types before surfacing them.

### 2.2 Domain Models

| Model | Key Fields | Firestore Collection |
|---|---|---|
| `UserModel` | `uid: String`, `name: String`, `email: String`, `role: String` (default `'user'`) | `users/{uid}` |
| `BookshelfModel` | `id: String`, `name: String`, `ownerId: String`, `createdAt: DateTime` | `bookshelves/{shelfId}` |
| `BookModel` | `id`, `title`, `link`, `totalPages: int`, `currentPage: int`, `progress: double`, `status: String`, `shelfId`, `ownerId`, `lastReadAt: DateTime?`, `author: String?`, `year: int?`, `needsOcr: bool` | `books/{bookId}` |
| `NoteModel` | `id`, `bookId`, `title: String`, `content: String`, `updatedAt: DateTime` | `notes/{noteId}` |

All `DateTime` fields are stored as **ISO 8601 strings** in Firestore (not `Timestamp`), which allows the domain layer to remain free of Firestore SDK types. The Firestore rules accept both formats via the `timestampValid()` helper to accommodate server-written timestamps from `FieldValue.serverTimestamp()`.

`BookModel.needsOcr` deserves specific mention: it is set once at upload time by the `_isBitmapOnlyPdf` heuristic in `new_book_screen.dart` and is thereafter **immutable** (enforced by Firestore rules — see Section 3). Its purpose is a one-time scan optimisation: if the PDF has no embedded text layer, the reader skips the text-extraction probe and routes directly to the Tesseract OCR pipeline, avoiding an unnecessary attempt at parsing an empty text layer on every page turn.

### 2.3 Firestore Collection Hierarchy

The schema uses **flat top-level collections** rather than sub-collections:

```
users/{uid}
bookshelves/{shelfId}
books/{bookId}
notes/{noteId}
```

This design was chosen for two reasons. First, flat collections avoid the recursive rule complexity that sub-collections introduce in Firestore Security Rules (e.g., `match /users/{uid}/books/{bookId}` requires duplicating ownership checks at every depth). Second, queries that cross shelf boundaries — such as "all books for this user regardless of shelf" (`allBooksProvider`) — are simple `where('ownerId', isEqualTo: uid)` queries on a flat collection. A sub-collection design would require a collection-group query with the attendant index costs and limitations.

Ownership relationships are encoded as foreign-key fields: `book.ownerId`, `book.shelfId`, and `note.bookId`. Notes ownership is resolved transitively through the parent book's `ownerId` field (via the `bookOwner()` function in Firestore rules), so a note cannot be accessed even if the caller knows its document ID unless they own the book it belongs to.

**Cascading deletes** are handled in `FirestoreDataSource` rather than Firestore triggers:

- **Delete shelf:** Batch-unshelve all books (`shelfId = ''`) → delete shelf doc.
- **Delete book:** Batch-delete all child notes → delete book doc → return `book.link` so the controller can purge the Supabase object, local file cache, thumbnail cache, Hive recents entry, and Hive OCR cache.

Batches are chunked at 500 operations to respect Firestore's batch write limit.

### 2.4 State Management — Riverpod Justification

The application uses `flutter_riverpod` for all shared state. `setState` is prohibited for anything beyond local UI ephemeral state (e.g., an animation controller or form focus node). The choice of Riverpod was driven by four specific requirements:

1. **Compile-time safety.** Riverpod's code-generated providers (`@riverpod` / `@Riverpod(keepAlive: true)`) are typed at compile time and cannot be read with the wrong type. This eliminates a class of runtime errors that `InheritedWidget` and `Provider` packages allow.

2. **`keepAlive` for auth and routing.** The `authStateProvider` (Firebase auth stream) and `routerProvider` (GoRouter instance) are declared with `keepAlive: true`. Without this, GoRouter would be garbage-collected and rebuilt on every widget tree rebuild, causing navigation state to reset.

3. **`StreamProvider.family` for per-entity streams.** Each book's notes, each shelf's books, and each book's OCR progress are watched as individual reactive streams via `StreamProvider.family`, keyed by ID. This avoids polling and ensures the UI updates in real time when Firestore emits a change.

4. **Test-overridable provider injection.** `featureFlagsProvider` is declared as an unimplemented provider that is overridden in `ProviderScope` with the singleton built in `main()`. In tests, the override can supply a fake `FeatureFlags` instance with any flag value, enabling deterministic feature-flag testing without network calls.

**Key providers:**

| Provider | Type | Purpose |
|---|---|---|
| `authStateProvider` | `StreamProvider<UserModel?>` | Firebase auth stream |
| `routerProvider` | `Provider<GoRouter>` (keepAlive) | GoRouter instance; watches auth + PIN state |
| `shelvesProvider` | `StreamProvider<List<BookshelfModel>>` | All shelves for current user (real-time) |
| `allBooksProvider` | `StreamProvider<List<BookModel>>` | All books for current user (real-time) |
| `booksByShelfProvider` | `StreamProvider.family<List<BookModel>, String>` | Books in one shelf |
| `notesByBookProvider` | `StreamProvider.family<List<NoteModel>, String>` | Notes for one book |
| `pdfPathProvider` | `FutureProvider.family<String, String>` | Local cache path (mobile) or URL (web) |
| `ocrPageTextProvider` | `FutureProvider.family<String, …>` | OCR pipeline: cache → render → recognise → clean → cache |
| `featureFlagsProvider` | `Provider<FeatureFlags>` | Remote Config singleton (overridden in `ProviderScope`) |

---

## Section 3 — Security Matrix

### 3.1 RBAC Matrix

The application defines two explicit roles (`user` and `admin`) plus the implicit `unauthenticated` state. A fourth conceptual row, *user (other)*, covers authenticated users attempting to access another user's resources.

| Role | `users` | `bookshelves` | `books` | `notes` | Supabase `pdfs` bucket | Edge Function (`pdf-proxy`) |
|---|---|---|---|---|---|---|
| Unauthenticated | Deny | Deny | Deny | Deny | Deny (upload) · Public read via URL | Public GET (no JWT required) |
| User (self) | Read own · Create self · Update name/email | Read own · Create · Update name · Delete | Read own · Create · Update mutable fields · Delete | Read (via book) · Create (via book) · Update · Delete | Upload under `{uid}/` · Read via public URL | GET any PDF URL |
| User (other) | Deny | Deny | Deny | Deny | Deny (upload) · Public read via URL | GET any PDF URL |
| Admin | Read all users | Read all shelves | Read all books | Read all notes | No elevated access | No elevated access |

**Notes on the matrix:**

- The Edge Function `pdf-proxy` is deployed `--no-verify-jwt` and is therefore publicly reachable. SSRF defences (see §3.4) compensate for the absence of auth.
- The Supabase `pdfs` bucket is set to **public read**, which is by design: PDF URLs are stored in `book.link` and fetched directly by the web reader. The security assumption is that URLs are unguessable (UUID-based millis timestamp path), not that the bucket is access-controlled.
- The `admin` role is read-only by rule. Firestore rules do not grant admins write access to any collection. Admin elevation requires direct Firestore access via the Firebase Admin SDK outside the client app.

### 3.2 Firestore Security Rules

**Source:** `firestore.rules`

The rules are structured around five helper functions that encapsulate repeated logic:

- `isSignedIn()` — checks `request.auth != null`
- `isOwner(uid)` — `isSignedIn() && request.auth.uid == uid`
- `isAdmin()` — resolves the caller's `users/{uid}.role` field from Firestore; returns `true` if `role == 'admin'`
- `changedFields()` — `request.resource.data.diff(resource.data).affectedKeys()` — used to enforce field-level immutability on update
- `timestampValid(field)` — accepts either a Firestore `timestamp` within a ±5-minute grace window, or a non-empty ISO 8601 `string`; rejects missing or empty values
- `bookOwner(bookId)` — fetches the parent book document and returns its `ownerId`; used by `notes` rules for transitive ownership

**Per-collection breakdown:**

**`users/{uid}`** — Profiles are owner-only. The `create` rule locks `role` to `'user'` at document creation, meaning a client can never self-elevate to admin. The `update` rule restricts mutable fields to `name` and `email` via `changedFields().hasOnly(['name', 'email'])`. User documents cannot be deleted.

**`bookshelves/{shelfId}`** — The `create` rule binds `ownerId` to `request.auth.uid` (a user cannot create a shelf on behalf of another). The `update` rule restricts changes to the `name` field only; `ownerId` and `createdAt` are permanently locked after creation.

**`books/{bookId}`** — The `create` rule enforces type correctness on all required fields and restricts `status` to the enum `['reading', 'on_hold', 'finished']`. The `update` rule allows only the six mutable fields: `title`, `currentPage`, `progress`, `status`, `lastReadAt`, `shelfId`. Fields such as `link`, `totalPages`, `needsOcr`, `author`, and `year` are immutable after creation — a client cannot rewrite the PDF URL after a book has been saved.

**`notes/{noteId}`** — Ownership is resolved transitively: the rule calls `bookOwner(resource.data.bookId)` to determine who owns the parent book, and only that user may read, create, update, or delete the note. This means that even if an attacker knows a note's document ID, they cannot access it without also owning the parent book.

**Default deny** — A catch-all `match /{document=**}` rule denies all reads and writes for any path not matched by an explicit rule.

### 3.3 Supabase Storage

The `pdfs` bucket uses path pattern `{uid}/{millis}.pdf`. Row-level security policies ensure a user may only upload under their own `{uid}/` prefix. Reads are public (intentional — see §3.1). Deletes are owner-enforced by the Supabase auth context passed by the Flutter client.

### 3.4 Edge Function SSRF Defences

The `pdf-proxy` Edge Function (`supabase/functions/pdf-proxy/index.ts`) is a public CORS proxy for the web reader. Because it accepts an arbitrary URL parameter, it requires explicit server-side request forgery (SSRF) protections:

- **Private IP rejection:** The function resolves the target hostname to A and AAAA DNS records and rejects any request resolving to a private or reserved IP range, including `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`, `169.254.0.0/16` (link-local / AWS metadata), and all IPv6 private ranges.
- **Blocked hostnames:** `localhost`, `*.local`, `*.internal`, and `metadata.*` (cloud metadata endpoints) are rejected by name before DNS resolution.
- **Redirect resistance:** The `fetch` call uses `redirect: manual`, preventing an attacker from placing a public hostname in front of a private target and exploiting a server-side redirect.
- **Size cap:** Declared `Content-Length` is checked against a 50 MB limit; streaming bytes are also tracked and the connection is aborted if the total exceeds 50 MB, defending against chunked-transfer-encoding abuse.
- **Timeout:** A 120-second fetch timeout prevents the function from hanging on slow upstreams.
- **Forced content type:** The response header is always overwritten to `application/pdf`, preventing an attacker from serving HTML through the proxy to the web reader's iframe.

### 3.5 App-Level PIN and Biometric

The application enforces a mandatory 6-digit PIN on every cold start (`lib/core/local/app_pin_service.dart`). The PIN is hashed using **SHA-256-crypt** (modular crypt format `$5$<salt>$<hash>`) via `package:crypt`. The raw PIN is never stored. The hash is kept in Hive `app_prefs` under key `app_pin_hash`. Verification uses constant-time comparison via `Crypt(stored).match(pin)`; `FormatException` and `RangeError` on malformed stored hashes return `false` rather than surfacing an exception.

Session state is tracked in `AppPinSession`, an in-memory-only object (never persisted). On logout, `AppPinSession.lock()` resets the flag, so the next app open requires re-entry.

Biometric authentication (`BiometricAuthService`, `lib/features/auth/data/biometric_auth_service.dart`) is an optional acceleration layer, not a sole credential. It is available at the login screen and the PIN entry screen. Web builds always return `false` from `isDeviceSupported()`, so the biometric path is unreachable on web without code changes.

### 3.6 Known Security Debts

The following items are documented in `CLAUDE.md` as deliberately deferred for demo scope:

- `web/index.html` loads `pdf.js` from `cdnjs.cloudflare.com` without a Subresource Integrity (SRI) hash. A CDN compromise could serve malicious JavaScript.
- No Content Security Policy (CSP), `Cross-Origin-Opener-Policy` (COOP), or `Cross-Origin-Embedder-Policy` (COEP) headers are set on the web build. The absence of COEP causes Tesseract.js SIMD WASM to degrade silently.
- The Hive `app_prefs` box is unencrypted on device. PIN hashes and OCR text are stored in plaintext.
- `tesseract_ocr 0.5.0` has been unmaintained since 2023 and has not received upstream security patches.

---

## Section 4 — Observability & Rollback

### 4.1 Structured Logging (AppLogger)

**Source:** `lib/core/logging/app_logger.dart`

All application logging is centralised through the static `AppLogger` class, which wraps `package:logger` with project conventions. The API exposes four levels:

```
AppLogger.debug(tag, message, {error})
AppLogger.info(tag, message)
AppLogger.warn(tag, message, {error, stackTrace})
AppLogger.error(tag, message, {error, stackTrace})
```

Tags follow an ALL\_CAPS\_SNAKE convention (`AUTH`, `OCR`, `TTS`, `LIBRARY`), enabling log filtering in the Firebase Crashlytics dashboard.

Printer configuration is environment-aware:
- **Debug builds:** `PrettyPrinter` with 8-frame error stack traces, 100-character line width, colored output.
- **Release builds:** `SimplePrinter` with timestamps and no color (suitable for cloud log ingestion).
- **Level threshold:** `Level.debug` in debug mode; `Level.info` in release (suppresses debug noise in production).

### 4.2 Crashlytics Implementation

**Source:** `lib/main.dart`, `lib/core/logging/app_logger.dart`

Firebase Crashlytics is instrumented at four distinct sites:

**Site 1 — Flutter framework errors** (`main.dart` lines 54–56):
```dart
FlutterError.onError = (details) {
  FlutterError.presentError(details);
  FirebaseCrashlytics.instance.recordFlutterFatalError(details);
};
```
Captures uncaught errors thrown inside Flutter's widget building and rendering pipeline.

**Site 2 — Platform dispatcher errors** (`main.dart` lines 58–61):
```dart
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```
Captures errors from the platform thread, including plugin channel errors and Dart isolate errors that propagate to the root.

**Site 3 — Zone error handler** (`main.dart` line 81):
```dart
(error, stack) {
  if (!kIsWeb) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }
}
```
Acts as a fallback catch for any error not intercepted by Sites 1 or 2. The entire `main()` body runs inside `runZonedGuarded`.

**Site 4 — AppLogger.error mirror** (`app_logger.dart` lines 57–68):
```dart
if (!kIsWeb && error != null) {
  FirebaseCrashlytics.instance.recordError(error, st, reason: _fmt(tag, message));
}
```
Any call to `AppLogger.error()` that carries a non-null `error` object automatically mirrors to Crashlytics with the log tag and message as the `reason` field. This surfaces non-fatal handled errors (e.g., a Firestore write timeout) in the Crashlytics dashboard alongside fatal crashes.

**`kIsWeb` guard:** All four sites are wrapped in `if (!kIsWeb)`. Crashlytics is not initialized on web (`firebase_crashlytics` does not support the web platform), and the `kIsWeb` guard prevents any attempt to call the plugin on that target. The guard is set before `setCrashlyticsCollectionEnabled()` (line 51), which also disables collection in debug builds (`!kDebugMode`).

### 4.3 Feature Flag System

**Source:** `lib/core/config/feature_flags.dart`

`FeatureFlags` wraps `FirebaseRemoteConfig` with a typed getter API. The class is constructed once in `main()` before `runApp`, initialized asynchronously, and then injected into the Riverpod provider graph via `featureFlagsProvider.overrideWithValue(featureFlags)`. All application code reads flags through this provider; direct calls to `FirebaseRemoteConfig.instance` are prohibited so that test overrides and the singleton lifecycle remain intact.

**Initialization is failure-safe:** the `initialize()` method wraps the Remote Config fetch in a try/catch that logs the error and falls through to defaults. The app never blocks on Remote Config — if the network is unavailable at first launch, defaults are used transparently.

**Configuration:**
- Fetch timeout: 10 seconds
- Cache TTL: 1 hour (`minimumFetchInterval: Duration(hours: 1)`)
- Default values: registered via `setDefaults(_defaults)` before `fetchAndActivate()`

**Active flags:**

| Remote Config key | Default | Effect |
|---|---|---|
| `ocr_fallback_enabled` | `true` | Master switch for the Tesseract OCR pipeline. When `false`, the reader uses embedded text only; scanned PDFs return empty text for TTS rather than invoking Tesseract. |

### 4.4 Rollback Plan — `ocr_fallback_enabled`

The OCR fallback pipeline (Tesseract on mobile, Tesseract.js on web) is the highest-risk runtime component: it executes WASM and FFI code on user devices, performs large memory allocations for page rasterisation, and can silently fail on devices with insufficient RAM. The feature flag provides a zero-redeploy kill switch.

**Rollback procedure:**

1. **Trigger:** Crashlytics alert for increased OCR-related fatal errors, or user reports of reader freezing on scanned documents.
2. **Action:** Navigate to Firebase Console → Remote Config → parameter `ocr_fallback_enabled` → set value to `false` → publish.
3. **Propagation:** Clients fetch the updated config within the 1-hour TTL. On the next app launch (or within 1 hour for apps already open), `FeatureFlags.ocrFallbackEnabled` returns `false`.
4. **Effect:** In `ReadingScreen`, the OCR branch is skipped. The TTS pipeline falls back to the embedded text layer only. For scanned PDFs with no text layer, TTS produces empty output rather than invoking Tesseract — no crash, no freeze.
5. **Recovery:** Once the root cause is identified and fixed (patch deployed), flip `ocr_fallback_enabled` back to `true`. Clients pick up the change within 1 hour.

**No client redeploy is required at any step.** The flag controls a branch inside `ReadingScreen` that is evaluated on every page-TTS request.

### 4.5 General Reversibility Tiers

Beyond the OCR flag, `CLAUDE.md` documents a three-tier reversibility model that governs all engineering decisions:

| Tier | Description | Protocol |
|---|---|---|
| **R0** | Irreversible — force-push, bulk Firestore delete, Supabase object purge, prod deploy, branch delete | Stop. Ask before proceeding. |
| **R1** | Costly to reverse — schema migrations, Firestore rule changes, dependency upgrades, hand-edits to generated files | Proceed, but state the justification first. |
| **R2** | Easily reversed — local file edits, new tests, refactors with green tests, stage/unstage | Just do it. |

This model ensures that the most dangerous operations (R0) require explicit human approval, while routine development (R2) does not incur unnecessary friction.

---

## Appendix — Configuration Touch-Points

| File | Purpose |
|---|---|
| `lib/main.dart` | Supabase URL + anon key; Hive box open; `FeatureFlags` init; Crashlytics guard; `ProviderScope` override |
| `lib/firebase_options.dart` | Firebase project config (generated by `flutterfire configure` — do not hand-edit) |
| `lib/core/config/feature_flags.dart` | Remote Config defaults + typed getters |
| `lib/core/network/pdf_fetcher.dart` | `kCorsProxyBase` constant (Edge Function URL) |
| `android/app/src/main/AndroidManifest.xml` | `<intent TTS_SERVICE>` query (Android 11+); `USE_BIOMETRIC` permission |
| `firestore.rules` | Firestore RBAC rules |
| `supabase/functions/pdf-proxy/index.ts` | Deno Edge Function (SSRF guard, size cap, CORS headers) |
| `assets/tessdata/` | Mobile Tesseract traineddata (manual download — see README) |
| `web/ocr/` | Tesseract.js worker + WASM + traineddata (manual download — see README) |
