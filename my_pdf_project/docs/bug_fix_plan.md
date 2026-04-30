# Bug Fix Plan — MyPDF

> Persistent task list across Claude Code sessions. Update checkboxes as fixes land.
> Source: 5-agent audit (architect / security / qa / flutter / firebase) — 2026-04-30.
> Severity rationale + file:line + fix sketch on each item.

**Legend:** `[ ]` pending · `[x]` done · `[~]` partial · `[!]` blocked
**Reversibility:** R0 (irreversible — STOP, ask) · R1 (costly — say why first) · R2 (easily reversed — just do it)

---

## CRITICAL (3)

- [x] **#1 — `_fetchUser` null-deref** · R2 ✅ done
  `lib/features/auth/data/firebase_auth_data_source.dart:42-62`
  Replaced `doc.data()!` with null guard + fallback to `_auth.currentUser` displayName/email. Register already creates doc (:23) — no change needed.
  **Evidence:** `flutter analyze` clean (1.1s) · `flutter test` auth screens 13 passed.

- [x] **#2 — Orphan blob on Firestore fail** · R2 ✅ done
  `lib/features/library/presentation/new_book_screen.dart`
  Added `_ensureTitleAvailable(title)` pre-check before upload. Extended `_uploadPdf` return record with `supabasePath`. On `createBook` returning null (Firestore failure), `storage.remove([supabasePath])` cleans up the orphan blob.
  **Evidence:** `flutter analyze` clean (1.7s) · new_book_screen tests 4 passed.

- [x] **#3 — SSRF + size cap in pdf-proxy** · R2 (code) → R1 (deploy as #18) ✅ code done
  `supabase/functions/pdf-proxy/index.ts`
  Added `ssrfCheck(hostname)` — resolves A+AAAA via `Deno.resolveDns`, rejects loopback / RFC1918 / link-local / ULA / multicast / CGNAT / `.internal` / `.local` / `metadata.*` / `localhost`. Switched `redirect: 'manual'` and reject 3xx (avoids DNS-rebinding via redirect). Added `TransformStream` byte counter on `upstream.body` for chunked-transfer cap. Forced `Content-Type: application/pdf`. Tightened cache to `max-age=60, must-revalidate`.
  **Note:** deno not installed locally — no type-check run. Live validation on deploy (#18 R1, gated). Verify in prod: `curl ".../pdf-proxy?url=http://169.254.169.254/"` → expect 403.

---

## HIGH (10)

- [ ] **#4 — Controller error swallowing** · R2
  `lib/features/library/presentation/library_controller.dart:128-211`
  `updateProgress`, `updateStatus`, `moveBook`, `createNote`, `updateNote`, `deleteNote` use bare `catch (_) { return false/null; }` → UI black hole.
  **Fix:** every catch → `catch (e, st) { state = AsyncValue.error(e, st); return false/null; }`. Keep return types.

- [ ] **#5 — TTS handler leak across pushes** · R2
  `lib/features/reader/presentation/reading_screen.dart:206-211`
  `dispose()` calls `_tts.stop()` un-awaited; handlers stay attached, can fire on disposed state.
  **Fix:** add `_isDisposed` flag; clear handlers (`setCompletionHandler(() {})` etc.) before stop. Guard `_speakCurrentPage` + handlers against post-dispose fire.

- [ ] **#6 — `_pdfPath` staleness on book switch** · R2
  `lib/features/reader/presentation/reading_screen.dart:521-525, 37`
  Cached on first non-null, never invalidated → wrong path on hot-reload / book switch.
  **Fix:** drop `_pdfPath` field. Read `ref.read(pdfPathProvider(book.link)).valueOrNull` at consumption sites (`_speakCurrentPage`).

- [ ] **#7 — `_webPdfBytes` cross-book contamination** · R2
  `lib/features/reader/presentation/reading_screen.dart:39, 276-279`
  Bytes cached forever, no key. Switch books on web → TTS reads wrong doc.
  **Fix:** track `String? _webPdfBytesKey = book.link`; invalidate on key change. Null in dispose. Optional: cache `sf.PdfDocument` per `book.link` instead of recreating per page (#28 medium).

- [ ] **#8 — Upload path collision** · R2
  `lib/features/library/presentation/new_book_screen.dart:105`
  `${uid}/${millis}.pdf` collides on same-ms uploads; `upsert: false` → throw.
  **Fix:** import `dart:math`, append random suffix: `'${uid}/${millis}_${Random().nextInt(0xFFFFFF).toRadixString(36)}.pdf'`.

- [ ] **#9 — Whitespace-only title accepted** · R2
  `lib/features/library/presentation/library_controller.dart:75-77, 155-161`
  Empty `_norm` collides on first call; `book_info_screen` falls back to "Untitled" masking it.
  **Fix:** `if (n.isEmpty) throw DuplicateNameException('Title cannot be empty.');` before duplicate scan in both `createBook` + `renameBook`.

- [ ] **#10 — Mid-read book delete stuck reader** · R2
  `lib/features/reader/presentation/reading_screen.dart:518-525`
  `bookAsync.hasValue && book == null` → reader stays on dead URL.
  **Fix:** inside `build()`, if `bookAsync.hasValue && book == null`, schedule `WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.go('/home'); })`. Return loading indicator meanwhile.

- [ ] **#11 — `deleteShelf` 500-op batch cap** · R2
  `lib/features/library/data/firestore_data_source.dart:33-46`
  Single batch unbounded; >499 books fails with `INVALID_ARGUMENT`.
  **Fix:** chunk to 499 ops/batch (last batch includes shelf delete). Mirror `deleteNotes:200-213`.

- [ ] **#12 — `watchBooksByShelf` missing ownerId filter** · R2
  `lib/features/library/data/firestore_data_source.dart:58-64`
  Defense-in-depth gap if rules lax.
  **Fix:** add `required String ownerId` param + `.where('ownerId', isEqualTo: ownerId)`. Update `booksByShelfProvider` in `library_providers.dart` to read uid from `authStateProvider`.

- [ ] **#13 — Email enumeration via auth errors** · R2
  `lib/features/auth/data/auth_repository_impl.dart:13-37`
  Distinct messages for `user-not-found` vs `wrong-password` → account-existence oracle.
  **Fix (login only):** collapse `user-not-found` + `wrong-password` + `invalid-credential` → single `'Incorrect email or password.'`. Keep `email-already-in-use` distinct on register (user's own attempt, not enumeration).

---

## MEDIUM (3)

- [ ] **#14 — `totalPages: 0` overwrite corruption** · R2
  `lib/features/library/data/firestore_data_source.dart:95-107`
  `updateReadingProgress` writes `totalPages` unconditionally; PDFView returns 0 during init.
  **Fix:** if `totalPages <= 0`, omit `totalPages` and `progress` from update map; only write `currentPage` + `lastReadAt`.

- [ ] **#15 — Logout doesn't clear Hive recents** · R2
  `lib/features/auth/presentation/auth_controller.dart:77-80`
  Next user inherits previous user's recent IDs (filtered out by joining, but stale data).
  **Fix:** after `signOut`, call `await _ref.read(recentBooksServiceProvider).clear()`. Add `clear()` method to `RecentBooksService` if absent (empty the box's `recent_book_ids` key). Skip local PDF cache purge for now.

- [ ] **#16 — `print` → `debugPrint`** · R2
  `lib/features/reader/presentation/reading_screen.dart:68, 73, 76, 79, 86, 90, 100, 147, 169, 200, 332, 335` (12 sites — verify count vs audit's 14)
  `lib/features/library/presentation/new_book_screen.dart:197, 239`
  `print` runs in release; `debugPrint` no-ops.
  **Fix:** replace each with `debugPrint`. Remove `// ignore: avoid_print` comments.

---

## R1 DEFERRED — need user approval (3)

- [ ] **#17 — Add `firestore.rules` + Supabase Storage RLS to repo** · R1
  No rules file in repo; managed in console only. Without rules, client-side ownerId filters bypassable.
  **Action plan:**
    1. Pull current rules from Firebase console → commit to `firestore.rules`.
    2. Reference in `firebase.json`: `"firestore": {"rules": "firestore.rules", "indexes": "firestore.indexes.json"}`.
    3. Tighten if needed: `request.auth.uid == resource.data.ownerId` on books/bookshelves; transitive book ownership for notes; `users/{uid}` self-only.
    4. Pull Supabase Storage policies via `supabase db dump` → commit `supabase/migrations/*.sql`. Enforce `(storage.foldername(name))[1] = auth.uid()::text` for INSERT/UPDATE/DELETE on `pdfs` bucket.
    5. Deploy: `firebase deploy --only firestore:rules`.

- [ ] **#18 — Deploy patched Edge Function** · R1
  Depends on #3.
  **Action:** `npx supabase functions deploy pdf-proxy --no-verify-jwt`. Verify SSRF rejection works in prod (curl `?url=http://169.254.169.254/` → expect 403).

- [ ] **#19 — Architect refactors** · R1 (large scope)
  Separate session.
  **Items:**
    - Add `lib/features/library/domain/library_repository.dart` returning `Either<Failure, T>` + impl in `data/`.
    - Move `pdfPathProvider` / `pdfThumbnailProvider` / `primePdfCache` / `_looksLikePdf` to `lib/core/network/pdf_cache_service.dart`.
    - Add `.autoDispose` to family / stream providers (`pdfPathProvider`, `pdfThumbnailProvider`, `bookByIdProvider`, `notesByBookProvider`, `booksByShelfProvider`).
    - Move `firestoreProvider` + `firebaseAuthProvider` from `auth/presentation/` to `lib/core/firebase/firebase_providers.dart`.
    - Replace 30+ hardcoded route strings with `AppRoutes.*` constants.
    - Move `recentBooksServiceProvider` out of `library/presentation/`.

---

## Out-of-scope notes (not actioned, recorded for memory)

- Domain coverage 98.6% (passes ≥80% gate). Datasource / service files at 0% — separate testing pass.
- 8 hardcoded `Color(0x...)` outside `AppColors` — separate theme cleanup.
- Android `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` over-broad for PDF-only app.
- pdf.js loaded from cdnjs without SRI in `web/index.html:36-39`.
- `supabase/.temp/` tracked in git (should be `.gitignore`d).

---

## Session log

- **2026-04-30** — fixed #1 (auth null-deref), #2 (orphan blob), #3 (SSRF + size cap code; deploy gated under #18). Halted at #4 — project shifted to demo mode. Resume with #4 next session.

## Workflow

When resuming in a new session:
1. Read this file first.
2. Pick lowest-numbered `[ ]` item (in-order — earlier critical, then high, then medium).
3. Mark `[~]` when starting, `[x]` when verified (analyze + tests green).
4. Note evidence inline if non-trivial: `[x] #N — fixed in commit abc123, flutter analyze clean, 104/1/0`.
5. R1 items require user confirmation before any write.
