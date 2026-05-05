# Tesseract Trained Data (Mobile OCR)

This directory MUST contain the following files before you can build the
mobile (Android / iOS) app with OCR enabled:

- `eng.traineddata` — English trained data
- `tha.traineddata` — Thai trained data

## Where to download

Use the **`tessdata_best`** repository for highest-accuracy trained models:

- English: https://github.com/tesseract-ocr/tessdata_best/raw/main/eng.traineddata
- Thai: https://github.com/tesseract-ocr/tessdata_best/raw/main/tha.traineddata

`tessdata_best` is the recommended choice — files are ~15 MB each but give
materially better OCR than `tessdata_fast`. Run-of-the-mill `tessdata`
also works if you want a middle ground.

## After downloading

Drop the two files directly in this directory:

```
assets/tessdata/
├── eng.traineddata     <-- you provide
├── tha.traineddata     <-- you provide
├── README.md           <-- this file
└── .gitkeep
```

The `tesseract_ocr` Flutter plugin auto-copies these from the app bundle
to `${appDocs}/tessdata/` on the first OCR call. No additional code
needed.

## Why aren't these committed?

`*.traineddata` files are 15 MB each. Committing them bloats the repo
and isn't friendly to non-OCR contributors. They're listed in
`.gitignore` and downloaded as a one-time user action. The web side
(`web/ocr/lang/*.traineddata.gz`) has the same constraint.

## Troubleshooting

If you see `Tesseract language data missing — see assets/tessdata/README.md`
at runtime, you forgot to drop the files in. Download them, then run
`flutter clean && flutter pub get && flutter run` so the asset bundle
picks them up.
