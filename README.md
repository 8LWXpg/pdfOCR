# pdfOCER

Make pdf searchable with ghostscript, and use powershell for multithreading.

## Requirements

- [ghostscript](https://www.ghostscript.com/), with Tesseract tessdata file at /bin/tessdata/eng.traineddata
- [pdftk](https://www.pdflabs.com/tools/)

All installed and added to the PATH

## Usage

> `ps> pdfOCR.ps1 <pdf> [<parallel threads>]`
