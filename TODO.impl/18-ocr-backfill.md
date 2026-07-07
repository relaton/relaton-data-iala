# 18 — Backfill: GLM OCR for scanned cover pages

**Priority:** P3 (gated by 16). Defensive — only needed if any cover
pages come back without a text layer.

## Why

Some older IALA PDFs are scanned images. `pdftotext` returns nothing
useful from those. GLM-OCR recovers the text from the image. The
fallback path must exist even if the happy path covers 95% of the
catalogue.

## Scope

### When the fallback triggers

In `IalaFetcher::CoverPageParser.parse(text)`:

1. Try `pdftotext -layout -l 1 <pdf>`.
2. If the output is empty or doesn't contain any of the regex anchors
   (`IALA (STANDARD|RECOMMENDATION|GUIDELINE|…)`, `Edition `, `urn:mrn`),
   invoke `CoverPageOcr#ocr_first_page`.
3. Re-parse the OCR output through `CoverPageParser`.

### What to backfill

After the initial scrape completes, run:

```bash
bundle exec ruby -Ilib -e '
  require "iala_fetcher"
  IalaFetcher::CoverPageOcr.new.ocr_first_page("pdfs/<hash>.pdf")
'
```

…for each PDF that failed text extraction. Store the OCR output in the
same cache as text-extracted covers; the parser doesn't care which path
produced the text.

### Acceptance

- [ ] `IalaFetcher::CoverPageParser` raises a typed `MissingCoverFields`
      error when no anchors are found, so the fetcher can catch and
      invoke OCR.
- [ ] `CoverPageOcr` reads the API key from `~/.zai-api-key` or
      `ENV["Z_AI_API_KEY"]`.
- [ ] OCR results are cached per (url, page-window) under
      `pdfs/ocr-cache/`.
- [ ] No doubles in specs; `cover_page_ocr_spec.rb` skips live API calls
      unless `ENV["Z_AI_LIVE"]` is set.
