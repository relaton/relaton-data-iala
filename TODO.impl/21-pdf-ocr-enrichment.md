# 21 — PDF + OCR enrichment of the full dataset

**Priority:** P2. **Status:** ❌ NOT DONE.

## Why

The full scrape (TODO 16) was run **without `--pdfs`** to keep wall-clock
under 30 minutes. As a result, the 863 emitted YAMLs carry only what's
exposed on the website:

- Title: ✓ from listing/product page (may have HTML entities)
- Edition: ✓ from product page Edition row
- Date: ✓ from product page Date row
- Committee: ✓ from product page Committee row
- **URN: ❌ only on cover pages** (`urn:mrn:iala:pub:s1070:ed2.0`)
- **Cover-page title typography: ❌** (the website sometimes uses
  different capitalisation/punctuation than the cover)
- **Normative/Informative classification: ❌** (only in the catalogue PDF)

For Standards (`S1010`-`S1070`) and the most recent Recommendations, the
URN is the most-missing field. Older documents also benefit from
cover-page committee attribution when the website's product page is
sparse.

## Scope

### Step 1 — Cover-page pass on current dataset

```bash
bundle exec ruby exe/iala-fetch --pdfs
```

This downloads every Work's English PDF (cache by URL SHA1 under
`pdfs/`), extracts page 1 via `pdftotext -layout -l 1`, falls back to
GLM-OCR for scans, and feeds the result through `IalaFetcher::CoverPageParser`
to recover: `label`, `code`, `title`, `edition`, `month_year`, `urn`.

### Step 2 — Re-emit YAMLs with cover-page fields merged

The PublicationFetcher already merges `cover&.title || detail.title` and
`cover&.edition || detail.edition` when `--pdfs` is on; re-running the
scrape with `--pdfs` is sufficient.

### Step 3 — Repeat for French and Spanish instances

The fetcher iterates each language's instance and OCRs its PDF
separately. The cache key includes the URL, so different-language PDFs
get separate cache entries.

## Acceptance

- [ ] `pdfs/` cache contains ~500+ PDFs (one per Work + per language instance).
- [ ] `pdfs/ocr-cache/` contains markdown for any scanned covers.
- [ ] At least the 7 Standards carry `ext.urn` matching their cover.
- [ ] Re-running `iala-fetch --pdfs` with no upstream changes produces zero `git diff` (cache makes it idempotent).
- [ ] `check_data.rb` still passes after enrichment.

## Open question

GLM-OCR API key is read from `~/.zai-api-key` or `ENV["Z_AI_API_KEY"]`.
The cron workflow in `relaton/support` will not have the key. **Decision
needed**: either (a) skip OCR in CI (cover-page fields committed by a
maintainer with the key), or (b) add the key as a GH secret and let CI
run the full pass.
