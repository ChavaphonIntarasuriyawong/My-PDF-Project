# Presentation Q&A — Professor Review

Likely questions a committee will ask about the codebase, with model answers grounded in the actual implementation.

---

## Domain Layer & Architecture

### Q1. Your `AuthRepository` returns `Either<Failure, UserModel>`. What is the purpose of the `Either` type here, and why not just throw exceptions?

**Answer:**

`Either<Failure, T>` (from the `dartz` package) makes failure an explicit part of the return type instead of a hidden side-effect. The function signature itself tells the caller "this can fail — handle both cases."

With exceptions, a failure can bubble up silently and crash the app if no one catches it. With `Either`, the caller is *forced* by the type system to handle the `Left` (failure) branch before they can use the `Right` (success) value. This is especially important in Flutter where an unhandled exception in a provider or build method causes a red error screen.

Concrete example: `login()` returns `Left(AuthFailure("wrong-password"))` instead of throwing `FirebaseAuthException`. The presentation layer pattern-matches on the result and shows a snackbar without any try/catch.

---

### Q2. The `library` feature has no repository interface — controllers go straight to the datasource. This breaks your own clean architecture pattern. Can you justify that decision, or is it a design debt?

**Answer:**

It is a deliberate trade-off, not an accident. The library feature is complex (books, shelves, notes, OCR, Supabase storage) and is the only backend in the app — there is no scenario where we would swap Firebase for a different library backend. Adding a repository interface would mean writing an extra layer of boilerplate (interface + implementation) that provides no practical benefit here.

The honest answer is: it is scope-driven design debt. The cost of not having the interface is low for a demo-scope app, but in a production codebase you would add it so that unit tests can inject a fake repository without touching Firestore.

---

### Q3. What is the rule about what can and cannot be imported inside `lib/features/*/domain/`? Why does this rule exist?

**Answer:**

The domain layer must contain only plain Dart — no `flutter/`, no `firebase_*`, no `supabase_*`, no `hive`, no platform packages of any kind.

The reason is testability and portability. Domain models and repository interfaces describe *what the app does*, not *how it does it*. If domain files import Firebase, you cannot test them without a Firebase emulator. By keeping domain pure Dart, you can run unit tests with zero platform setup and swap the data backend (e.g., Firebase → REST API) without touching domain code.

---

### Q4. `BookModel` has a `progress` field described as calculated from `currentPage / totalPages`. Why is it also stored in Firestore instead of being computed on the fly?

**Answer:**

`progress` is stored redundantly in Firestore to enable server-side sorting and filtering without a client-side computation pass. If you wanted to show "books sorted by reading progress" across a large library, a Firestore query can `orderBy('progress')` in a single round-trip. If progress were only a computed getter on the model, you would have to fetch all books, sort in Dart, and then display — which doesn't scale.

The trade-off is that you must keep `progress` in sync whenever `currentPage` or `totalPages` changes, which is done in `LibraryController` when updating page progress.

---

## Firestore & Security

### Q5. Walk me through your Firestore rules. How does the system prevent User A from reading or deleting User B's books?

**Answer:**

Every document in the `books` collection has an `ownerId` field set to the Firebase Auth `uid` of the user who created it. The Firestore security rules check:

```
allow read, write: if request.auth != null && request.auth.uid == resource.data.ownerId;
```

`request.auth.uid` is the identity token Firebase verifies server-side — it cannot be spoofed by the client. `resource.data.ownerId` is the value stored in the document. If they don't match, the operation is rejected before it reaches your app code.

Admins (users with `role == 'admin'` in their `users` doc) get an additional `read` grant via a role check:

```
allow read: if request.auth != null
  && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
```

---

### Q6. Your `notes` collection has no `ownerId` — only a `bookId`. How do Firestore rules enforce that only the book's owner can access those notes?

**Answer:**

The rules perform a cross-document lookup at evaluation time:

```
allow read, write: if request.auth != null
  && get(/databases/$(database)/documents/books/$(resource.data.bookId)).data.ownerId
     == request.auth.uid;
```

For each note access, Firestore reads the parent book document and compares its `ownerId` to the authenticated user. This is a `get()` call inside the rule — it costs one extra read but avoids duplicating `ownerId` on every note.

The downside is cost: every note read/write burns an extra Firestore read for the ownership check.

---

### Q7. You store dates as ISO 8601 strings instead of Firestore `Timestamp`. What problems does this cause, and why did you choose strings?

**Answer:**

**Problems strings cause:**

- You cannot use Firestore's native `orderBy` on a string date field the same way you would a `Timestamp` — lexicographic sort works correctly only if the format is strictly `YYYY-MM-DDTHH:MM:SS` with no ambiguity.
- Time zone handling is manual — if a string has no `Z` suffix it is ambiguous.
- Firestore TTL policies require native `Timestamp` fields.

**Why we chose strings:**

Consistency across platforms. Flutter's `DateTime` serializes cleanly to ISO 8601 strings. The `Timestamp` type requires the Firebase SDK on both ends, and in the domain layer (pure Dart) we cannot depend on Firebase types. Using strings keeps the domain model free of Firebase imports while remaining human-readable in the Firestore console.

---

### Q8. The `whereIn` query has a hard Firestore cap of 30 items. How did you handle this in `watchUserNotesCount`, and what happens with more than 30 books?

**Answer:**

`watchUserNotesCount` chunks the `bookIds` list into slices of 30, fires one `whereIn` query per chunk, and merges the resulting streams using `StreamZip` (or `Rx.combineLatest`). The total count is the sum across all chunk streams.

For a user with 90 books: 3 parallel Firestore streams run, each watching 30 book IDs. The count is the sum of all three.

The edge case is that adding book 31 causes a new stream to be created, which requires the provider to re-subscribe — this is handled by `ref.watch` rebuilding when the book list changes.

---

## State Management (Riverpod)

### Q9. What is the difference between `ref.watch()` and `ref.read()` in Riverpod? Give a concrete example from your code of when each is appropriate.

**Answer:**

- `ref.watch(provider)` subscribes to the provider and rebuilds (or re-executes) whenever the provider's value changes. Use it inside `build()` methods or provider bodies where you want reactive updates.
- `ref.read(provider)` reads the current value once without subscribing. Use it inside event handlers or controller methods where you don't want a rebuild triggered by the read itself.

**Concrete example:**

In `ReadingScreen`, the widget uses `ref.watch(bookByIdProvider(bookId))` to rebuild the page counter whenever `currentPage` changes in Firestore.

In `LibraryController.deleteBook()`, it uses `ref.read(firestoreDataSourceProvider)` to get the datasource instance once and call a method on it — no rebuild needed, it is a fire-and-forget action.

---

### Q10. `pdfPathProvider` is a `family` provider keyed by URL. What would go wrong if you had used a regular provider instead?

**Answer:**

A regular (non-family) provider is a singleton — there is only one instance. If two books are open simultaneously, or the provider is reused between navigations, the second `pdfPathProvider` call would return the cached path from the *first* URL, showing the wrong PDF.

`family` creates a separate provider instance per unique argument (URL in this case), so `pdfPathProvider("url-a")` and `pdfPathProvider("url-b")` are independent caches. Each is disposed separately when no widget is watching it.

---

### Q11. You stream books from Firestore via `booksByShelfProvider`. What happens to that stream subscription when the user navigates away from the shelf screen? How do you prevent memory leaks?

**Answer:**

Riverpod manages the subscription lifetime automatically. A `StreamProvider` keeps the Firestore listener open as long as at least one `ref.watch` subscriber is active. When the shelf screen is popped from the navigation stack, the widget is disposed, the `ref.watch` subscription drops to zero listeners, and Riverpod cancels the Firestore snapshot listener.

For providers marked `keepAlive: true` (e.g., `featureFlagsProvider`), the subscription stays open for the app's lifetime intentionally. For regular providers, disposal is automatic.

In controllers, streams that are started manually (e.g., background OCR sweep) are cancelled via `ref.onDispose(() => _subscription?.cancel())`.

---

## Platform & PDF Pipeline

### Q12. Your `pdf_fetcher.dart` routes web requests to the Edge Function proxy. Explain the CORS problem it solves.

**Answer:**

Browsers enforce the **Same-Origin Policy**: a web page at `https://mypdf.app` can only fetch resources from `https://mypdf.app` by default. Fetching a PDF from `https://some-external-site.com/paper.pdf` is blocked unless that site's server returns a `Access-Control-Allow-Origin` header permitting it — and most static file servers do not.

The Edge Function (`pdf-proxy`) runs server-side (Deno on Supabase). It fetches the external PDF on behalf of the browser, then returns the bytes to the browser with permissive CORS headers. Since the request comes from Supabase's server (not the browser), the external site's CORS policy is irrelevant.

Mobile apps do not have this problem — native HTTP clients are not subject to CORS.

---

### Q13. What is the `needsOcr` flag on `BookModel`, and how is it determined at upload time?

**Answer:**

`needsOcr` is a boolean that signals whether the PDF is a scanned image (bitmap-only) with no embedded text layer. When `true`, the reader skips the text-extraction probe entirely and routes directly to Tesseract OCR for TTS.

It is set at upload time by the `_isBitmapOnlyPdf` heuristic in `new_book_screen.dart`. The heuristic reads the first few pages with Syncfusion and checks whether any extractable text is returned. If all sampled pages return empty strings, the PDF is classified as bitmap-only and `needsOcr = true` is saved to Firestore with the book document.

Setting it at upload (once) is better than checking at read time (every page navigation) because OCR detection via Syncfusion is non-trivial CPU work. Paying the cost once at upload means the reader can branch instantly.

---

### Q14. You use conditional imports for OCR. What happens at compile time on mobile vs web? What would break if you imported `ocr_data_source_io.dart` directly in a web build?

**Answer:**

`ocr_data_source.dart` contains:

```dart
import 'ocr_data_source_io.dart'
    if (dart.library.js_interop) 'ocr_data_source_web.dart';
```

At compile time, the Dart compiler picks exactly one branch:
- **Mobile/desktop**: `dart.library.js_interop` is absent → `_io.dart` is compiled in.
- **Web**: `dart.library.js_interop` is present → `_web.dart` is compiled in.

The unselected file is completely excluded from the build — it is as if it doesn't exist.

If you imported `ocr_data_source_io.dart` directly in a web build, the compiler would try to include `tesseract_ocr` (an FFI package that wraps a native `.so`/`.dylib`), `dart:io`, and `path_provider` — none of which exist in the browser runtime. The web build would fail with "Target of URI doesn't exist" or "dart:io not available on web" errors.

---

## GoRouter & Auth Flow

### Q15. Trace the redirect logic for a cold-start where the user is logged in, has set a PIN, but hasn't unlocked this session yet.

**Answer:**

1. App starts → `authStateProvider` emits a loading state → router redirects to a splash/loading screen to avoid a login flash.
2. Firebase resolves the auth token → `authStateProvider` emits `UserModel` (logged in).
3. Router's `computeRedirect` sees: auth ✓, PIN set ✓ (checked via `AppPinService.hasPin()`), PIN unlocked this session? — NO (checked via `PinSessionService.isUnlocked`, which is in-memory and resets on kill).
4. Redirect fires to `/pin-lock` (the app-level PIN gate screen).
5. User enters correct PIN → `PinSessionService.unlock()` marks the session unlocked in memory.
6. Router re-evaluates (because the session state changed) → no redirect condition matches → user lands on `/home`.

The key insight is that `routerProvider` watches the session state as a reactive provider, so the redirect fires automatically when `PinSessionService` changes — no manual `context.go()` needed from the PIN screen.

---

### Q16. Why does your router watch `authStateProvider` as a stream rather than a one-time future? What UX bug would appear if you used a future?

**Answer:**

Firebase Auth is session-persistent — the auth state can change while the app is running (user logs out, token is revoked, session expires). If the router read auth state once at startup via a future, it would never react to a mid-session logout. The user could tap "logout", the auth future would be stale, and the router would keep showing protected screens.

With a stream, every emission (login, logout, token refresh) triggers `computeRedirect`. When the user logs out, `authStateProvider` emits `null`, the router immediately sees the unauthenticated state, and redirects to `/login` — without any manual navigation call from the logout button.

---

## Hard / Design Questions

### Q17. If two devices update `currentPage` simultaneously, what happens? Does your app handle this conflict?

**Answer:**

No conflict resolution exists. The app performs a simple `update({'currentPage': page, 'progress': value})` Firestore call. If two devices write at nearly the same time, the last write wins — Firestore applies writes sequentially and the final state reflects whichever write arrived last at the server.

For reading progress this is acceptable: both devices are reading the same book, and "last write wins" roughly means "most recent page position wins," which is the reasonable behavior.

A proper solution for multi-device sync would be to use Firestore **transactions** (read-modify-write atomically) or to store progress as a map keyed by device ID and merge on the client. For demo scope, last-write-wins is a deliberate simplification.

---

### Q18. Your OCR cache key is `ocr_v1_{bookId}_{pageIndex}`. Why is the `v1` prefix significant?

**Answer:**

The `v1` prefix is a schema version for the cache entry. If the OCR engine is upgraded (e.g., switching from Tesseract 4 LSTM to a different model, or changing the cleaning/post-processing pipeline), the output text for the same page may be substantially different or better.

Without a version prefix, the app would read stale cached text from the old engine and never re-run OCR on upgraded books. By bumping the prefix to `v2`, all old `v1_*` keys become orphaned — they are ignored on read (cache miss) and the new engine runs fresh. The old keys are cleaned up lazily via `OcrCacheService.purgeBook()` or a one-time migration.

---

### Q19. Deleting a book triggers 5 cascading operations. If step 3 (clear local cache) fails, what is the state of the system? Is it consistent?

**Answer:**

No, it is not fully consistent. The delete is not atomic across all five operations. If steps 1 and 2 succeed (notes deleted from Firestore, PDF removed from Supabase) but step 3 fails (local file delete throws):

- The book is gone from the backend — it cannot be recovered.
- A stale PDF file remains in the device's local cache directory, wasting storage but causing no functional error (the app will never reference it again since the book document is gone from Firestore).
- Steps 4 and 5 (recents + OCR cache) may or may not have run.

The system is *eventually* recoverable: the stale file is harmless and will be removed on OS cache pressure or app reinstall. But it is not transactional.

A proper solution would be a **two-phase approach**: soft-delete the Firestore document first (mark `deleted: true`), clean up local and remote storage asynchronously with retry logic, then hard-delete the document. This is out of scope for demo purposes, and the current approach is documented as a known limitation.

---

### Q20. You have two backends: Firebase and Supabase. A new team member asks why not use just one. What is your answer?

**Answer:**

Each backend was chosen for what it does best:

**Firebase** is used for Auth, Firestore, and Crashlytics because:
- Firebase Auth is battle-hardened, has built-in session persistence, and integrates directly with Firestore security rules via `request.auth.uid`.
- Firestore real-time streams (`snapshots()`) make the UI reactive to data changes with minimal code.
- Crashlytics provides production crash reporting with zero backend setup.

**Supabase** is used for PDF storage and the CORS proxy because:
- Firebase Storage exists but is priced per GB downloaded — PDFs are large and frequently fetched, making Supabase Storage more cost-effective at scale.
- The Edge Function (Deno) gives us a simple, deployable serverless CORS proxy without needing a separate Node.js server or Cloud Function.

The downside is operational complexity — two dashboards, two SDKs, two sets of security rules (Firestore rules + Supabase RLS). For a solo developer or small team, consolidating on one (Firebase Storage or Supabase Auth) would reduce that overhead. For this project, the split was a deliberate capability-vs-cost decision.

---

*Generated for presentation preparation — answers reflect the actual implementation in this repository.*
