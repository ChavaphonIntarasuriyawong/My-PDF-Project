# OCR Fallback — Manual QA Matrix (Wave 4)

This matrix walks the OCR fallback feature end-to-end on every supported
platform. Run before each release that touches the OCR pipeline. Tester fills
the **Actual** column and the bottom Sign-off block; leave **Actual** blank in
git.

## Prerequisites

- Build flavor: `--release` for Android/iOS, `flutter build web --release` for Chrome.
- Test fixtures (place under `test/fixtures/` or a Drive folder accessible to the test account):
  - `born_digital_eng.pdf` — selectable text, English.
  - `scanned_eng.pdf` — image-only scan, English.
  - `scanned_tha.pdf` — image-only scan, Thai (or mixed Thai/English).
  - `scanned_long.pdf` — 200+ page Thai scan for memory soak.
- Tessdata files dropped at `assets/tessdata/eng.traineddata` and
  `assets/tessdata/tha.traineddata`.
- Web tessdata at `web/ocr/lang/eng.traineddata.gz` and
  `web/ocr/lang/tha.traineddata.gz`.
- Firebase Console → Remote Config → `ocr_fallback_enabled` toggle accessible.
- Test Firebase account, signed in on each device.

## Severity legend

- **block** — feature unusable; ship-blocker.
- **major** — feature degraded but workable; fix before next release.
- **minor** — polish.

## Matrix

| # | Scenario | Platforms | Expected | Actual | Severity |
|---|---|---|---|---|---|
| 1 | Born-digital PDF, tap Speak on page 1 | Android · iOS · Chrome | TTS speaks within ~1 s. No "Extracting text…" progress strip. `debugPrint`/devtools: `ocrPageTextProvider` is **not** invoked. | | |
| 2 | Scanned English PDF, tap Speak on page 1 (cold cache) | Android · iOS · Chrome | Progress strip appears with "Extracting text from scanned page…". TTS begins within ~10 s on mobile, ~15 s on web. Recovered text matches the visible page (>50 chars). | | |
| 3 | Scanned English PDF, tap Speak again on page 1 | Android · iOS · Chrome | No progress strip — second tap returns from Hive cache instantly. TTS starts <1 s. | | |
| 4 | Scanned English PDF, navigate to page 2 within 30 s of page 1 | Android · iOS · Chrome | Background pre-OCR has already cached pages 2–5. Page 2 Speak is instant (no progress strip). | | |
| 5 | Scanned Thai PDF, tap Speak on page 1 | Android · iOS · Chrome | Progress strip appears, TTS speaks Thai. Accuracy "acceptable" (>60% words on a clean scan). One-time snackbar: "Thai OCR accuracy varies; report bad results in Settings." | | |
| 6 | Mid-OCR navigation: open scanned book, wait until "Extracting…" chip appears in app bar, immediately back out and open a different book | Android · iOS · Chrome | Previous book's background OCR is cancelled — chip disappears. New book starts cleanly. No crash, no stale "X / Y pages" left in app bar. Devtools: no orphan `Future` errors logged. | | |
| 7 | Kill switch: in Firebase Console set `ocr_fallback_enabled=false`. Cold-restart app. Tap Speak on a scanned PDF. | Android · iOS · Chrome | Original snackbar appears: "No readable text on this page (scanned PDF?)". OCR pipeline never invoked (no progress strip, no Hive writes under `ocr_v1_*`). | | |
| 8 | Cascading delete: scanned book in step 4 has cached OCR → delete the book from Library. | Android · iOS · Chrome | After delete, `Hive.box('app_prefs').keys.where((k)=>k.startsWith('ocr_v1_<deletedBookId>_'))` is empty. Supabase object purged, recents updated, no orphan thumbnails. | | |
| 9 | Web Worker spawn check: scanned PDF, page 1, before tapping Speak open Chrome DevTools → Application → Service Workers + Workers panel. Tap Speak. | Chrome | A Tesseract.js dedicated worker appears in the Workers list. Performance tab shows no main-thread task >100 ms during recognition. | | |
| 10 | Long-PDF memory soak: open `scanned_long.pdf` (200 pages), let background pre-OCR run for 5 minutes. | Android (4 GB device) · iOS · Chrome | Devtools heap stays under 1 GB (mobile) / 1.5 GB (Chrome). No OOM kill. `pdfPageImageProvider` shows it's invalidated between pages (only 1–2 page images in memory at a time). | | |
| 11 | Asset-missing failure path: rename `assets/tessdata/eng.traineddata` to a wrong name, rebuild, tap Speak on scanned PDF. | Android · iOS | App does not crash. Snackbar: clear error mentioning `assets/tessdata/README.md`. After restoring the asset, feature works. | | |
| 12 | Web asset-missing: delete `web/ocr/tesseract.min.js`, rebuild, tap Speak on scanned PDF. | Chrome | App does not crash. Snackbar mentions `web/ocr/README.md`. | | |
| 13 | Bundle size before/after: `flutter build apk --release --analyze-size`. | Android | Document delta in PR. Expected ~+12 MB (Tesseract + 2 traineddata files). Flag if delta >20 MB. | | |
| 14 | First-OCR cold start measurement: stopwatch from Speak tap to first audible TTS word on a fresh install (cache cold). | Android · iOS · Chrome | Mobile ≤8 s, web ≤15 s on broadband. | | |
| 15 | TTS interrupt during OCR: tap Speak on scanned PDF, then tap Stop while progress strip is still visible. | Android · iOS · Chrome | OCR completes silently (or is cancelled cleanly), TTS does **not** start. No crash, no duplicate playback if Speak is tapped again. | | |
| 16 | Network-loss during web OCR: Chrome DevTools → Network → Offline, then tap Speak on a remote scanned PDF (CORS proxy in use). | Chrome | Existing snackbar "PDF download timed out / proxy error". OCR pipeline gated behind successful page-image render — no half-state. | | |
| 17 | Encrypted PDF on scanned page | Android · iOS · Chrome | Page render fails before OCR is even attempted. User sees existing "Encrypted PDF unsupported" snackbar (not the OCR snackbar). | | |
| 18 | Remote Config flip mid-session: app open on scanned page, flip `ocr_fallback_enabled` to `false` in Firebase Console, wait 1 h TTL or trigger refresh | Android · iOS · Chrome | Background OCR loops stop within one TTL. Currently-running recognise calls are allowed to finish but no new ones are started. UI gracefully reverts to "scanned PDF?" snackbar on next page. | | |

## Sign-off

| Tester | Device + OS | Build SHA | Date | Pass/Fail |
|---|---|---|---|---|
|  | Android (Pixel 6, API 34) |  |  |  |
|  | iOS (iPhone 13, iOS 17) |  |  |  |
|  | Chrome (desktop, latest stable) |  |  |  |
|  | Chrome (Android, latest stable) |  |  |  |

## Bug-report template

When a row fails, file an issue with:
- Row number from this matrix.
- Build SHA + platform.
- Repro steps (copy from row, plus any deltas).
- Expected vs actual.
- Logs: `flutter logs` for mobile, DevTools console for web.
- Severity per the legend above.
