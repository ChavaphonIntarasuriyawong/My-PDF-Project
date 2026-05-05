# Tesseract.js Assets (Web OCR)

These files are required for OCR on the **web** build only. They're
loaded lazily on the first OCR call (no cold-start cost for users
who never trigger it). Mobile uses the `tesseract_ocr` Flutter
plugin — see `assets/tessdata/README.md` for that side.

## Required files

```
web/ocr/
├── tesseract.min.js                <-- Tesseract.js v5 main script
├── worker.min.js                   <-- Web Worker entry point
├── tesseract-core-simd.wasm        <-- WASM core (SIMD build)
├── lang/
│   ├── eng.traineddata.gz          <-- English (gzipped)
│   └── tha.traineddata.gz          <-- Thai (gzipped)
├── README.md
└── .gitkeep
```

## Where to download

### `tesseract.min.js` and `worker.min.js`

From the Tesseract.js v5 distribution on jsDelivr:

- https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js
- https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/worker.min.js

### `tesseract-core-simd.wasm`

From the `tesseract.js-core` package on jsDelivr:

- https://cdn.jsdelivr.net/npm/tesseract.js-core@5/tesseract-core-simd.wasm

### Trained data (`lang/*.traineddata.gz`)

Use the gzipped variants from `tessdata_best`:

- https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata
- https://github.com/tesseract-ocr/tessdata_best/raw/main/tha.traineddata

Then gzip them — Tesseract.js fetches `.traineddata.gz` by default:

```sh
gzip -k eng.traineddata     # produces eng.traineddata.gz, keeps original
gzip -k tha.traineddata
```

Place the `.gz` files into `web/ocr/lang/`.

## Why aren't these committed?

These add up to about 25 MB. We don't bloat the git repo with binary
assets. They're listed in `.gitignore` and re-downloaded as a one-time
setup per machine. Build pipelines that need them should fetch them
in CI.

## Why same-origin (no CDN)?

Web Workers and WASM both have stricter cross-origin restrictions
than regular scripts. Serving everything from the app's own origin
sidesteps Service Worker / CSP / COEP headaches. Tesseract.js v5
deprecated their default CDN in favor of self-hosting anyway.

## Wiring

Loaded by `lib/features/library/data/ocr_data_source.dart` →
`WebOcrDataSource` on first `recognize` call. Configuration:

```js
Tesseract.createWorker(['eng', 'tha'], 1, {
  workerPath: 'ocr/worker.min.js',
  corePath: 'ocr/',
  langPath: 'ocr/lang/',
});
```

The paths above are relative to the deployed web root (e.g. served
from `/ocr/...` at runtime).
