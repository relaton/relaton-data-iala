# 27 — Technical Documents Catalogue reconciliation + abstracts

**Priority:** P1.
**Status:** ✅ DONE.
**Issue:** relaton/relaton-data-iala#10.

## Why

The category listings the site walk reads lag behind new publications.
The Technical Documents Catalogue (Ed 11.0, June 2026) is IALA's complete
inventory: it links to each `/product/<slug>/` page and gives a Summary per
document. Before this item, 13 catalogue codes were missing from `data/`
and only the 12 standards files had an abstract.

Verified gap (the issue list was slightly off — G1067 exists as parts
g1067-0..3, S1030 exists, G1161 was missing):
G1023, G1141, G1143, G1150, G1154, G1155, G1156, G1158, G1160, G1161,
G1162, G1163, G1164.

## Scope (delivered)

- `IalaFetcher::TechnicalCatalogue` — `.latest_url` (newest
  `Technical-documents-Catalogue-Ed-N.M…pdf` on `/guidance-publications/`),
  `#product_urls`, `#entries`, `#summary_for(code, edition:)`,
  `.primary_code` (anchored: annexes such as `G1045 Annex` do not match).
- `PublicationFetcher` — `technical_catalogue:` kwarg; `#run` adds catalogue
  products the walk missed (filtered by the requested categories, before
  the fetch when the slug shows the code letter); `#run_reconciliation`
  adds only products missing from `data/`. Known codes count English items
  only. Catalogue summary fills the English Work/Instance abstract when the
  product page has none **and** the editions match.
- `IalaFetcher::AbstractBackfill` — adds summaries to existing English
  items without an abstract (same edition rule), through `YamlStore#write`.
- CLI: `fetch --[no-]catalogue --catalogue-url=`, new `catalogue` task.
- Data: 28 new files — the 13 missing guidelines plus G1081 Ed 2.1, which
  `data/` had only in Spanish (Ed 1.0); each is a Work + an English
  Instance. Abstracts added to 432 existing files (472 of 842 English
  files now have one).

## Acceptance

- [x] The 13 codes are in `index-v1.yaml` / `index-v2.yaml`.
- [x] Catalogue summaries as `format: text/plain` abstracts; standards keep
      their HTML product-page abstracts.
- [x] Specs without doubles; catalogue PDFs built by `spec/support/pdf_builder.rb`.

## Known limits

- A few soft hyphens stay where the joined word does not occur elsewhere in
  the catalogue (`establi-shed`, `scena-rios`), and some summaries keep
  run-together words that the PDF sets without spaces.
- Standards (S-codes) are catalogue section pages, not table rows — no
  summary is parsed for them (their product pages have abstracts).
- `check_data.rb` reports 12 round-trip mismatches in the standards files
  (`|2+` block scalars in HTML abstracts). These were there before and are
  not touched by this item.
