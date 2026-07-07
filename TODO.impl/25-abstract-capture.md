# 25 — Abstract capture

**Priority:** P2.
**Status:** ✅ DONE.

## Why

The task brief said "also need to encode the abstract". Standards (S1010,
S1020, S1070) carry website-side abstracts in `<div class="page" title="Page N">`
inside the product detail page. Other categories (recommendations,
guidelines, manuals, model courses, reports) do not.

`IalaFetcher::ProductPage` already extracted `abstract_html` from that
container, but `PublicationFetcher` wasn't propagating it to the YAML.

## Scope (delivered)

- `PublicationFetcher#abstracts_for(group)` — collects one abstract per
  language that has one on its product page. Work carries all available
  language abstracts.
- `PublicationFetcher#instance_abstract(detail, lang)` — single abstract
  for the Instance's language.
- Relaton's `abstract` field is a collection of `Abstract < LocalizedMarkedUpString`
  hashes. Each entry is `{ content: <html>, language: <iso-639-3>, format: "text/html" }`.
- `PublicationFetcher#build_work_hash` now returns `[hash, work_docid]`
  so the caller can derive the matching filename (was previously a silent
  bug where Work YAMLs were named without the edition suffix).
- `ext.webpage` is now also populated on Works (the canonical English
  product page URL), not just Instances.
- New `spec/iala_fetcher/publication_fetcher_spec.rb` — 6 examples
  covering Work + Instance emission, hasInstance/instanceOf relations,
  abstract capture, title typography fallback.

## Acceptance

- [x] At least the 7 Standards emit a `Work` YAML with an `abstract:` block.
- [x] Work filename matches Instance filename stem pattern
      (`s1070-2.0.yaml` ↔ `s1070-2.0-e.yaml`).
- [x] `ext.webpage` populated on Works (canonical English product page).
- [x] Specs cover the abstract path (publication_fetcher_spec).

## Out of scope

- Cover-page abstracts — IALA cover pages don't carry abstracts, only
  title/edition/date/URN.
- Catalogue-text abstracts (the catalogue PDF has 1–2 sentence summaries
  per publication) — would require parsing the catalogue PDF separately.
