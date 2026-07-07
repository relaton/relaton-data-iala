# 12 — Specs

**Status:** 🟡 PARTIAL — 42 of ~55 planned examples done.
**Priority:** P1.

## Current coverage (2026-07-07)

| Component | Status | Examples |
|-----------|--------|----------|
| Http | ✅ | 5 |
| Source | ✅ | 5 |
| YamlStore | ✅ | 3 |
| Docid | ✅ | 17 |
| CataloguePage | ✅ | 5 |
| ProductPage | ✅ | 3 |
| CrossLanguageLinker | ✅ | 6 |
| CoverPageParser | ✅ | 3 |
| PdfDownloader | ❌ | — |
| CoverPageOcr | ❌ | — |
| PublicationFetcher (integration) | ❌ | — |
| Indexer | ❌ | — |
| Scrape (Thor CLI) | ❌ | — |

See [24-missing-specs.md](24-missing-specs.md) for the gap plan.

## Why

The dataset must be byte-stable across runs and survive relaton-bib API
changes. Specs guard both. Global rule: **never use `double()`** —
instantiate real objects or `Struct.new` for plain data.

## Scope

### Spec layout

```
spec/
  spec_helper.rb                          # mirror OIML
  iala_fetcher/
    http_spec.rb                          # NetHttp via webmock
    source_spec.rb
    yaml_store_spec.rb                    # round-trip via Relaton::Bib::Item
    docid_spec.rb                         # all four constructors
    catalogue_page_spec.rb                # fixture HTML → rows
    product_page_spec.rb                  # fixture HTML → Detail
    cross_language_linker_spec.rb
    pdf_downloader_spec.rb
    cover_page_ocr_spec.rb                # no live API calls — ENV-driven skip
    cover_page_parser_spec.rb
    publication_fetcher_spec.rb           # end-to-end with Http::Fake
    indexer_spec.rb
    scrape_spec.rb                        # smoke test of the Thor CLI
  fixtures/
    iala/
      standards.html                      # archived listing page
      product_s1070.html                  # archived product detail
      product_r0126.html
      cover_s1070.txt                     # pdftotext output of first page
      cover_s1070.pdf
      r1016_fr.html
```

### What every spec must do

- Use `IalaFetcher::Http::Fake` with a fixture table for any network
  call. Never `allow_any_instance_of` or `double`.
- For value objects (`Docid`, `Source`), test construction, accessors,
  and derived forms (id, filename_stem, urn).
- For fetchers, exercise the full path with a small but real fixture
  set and assert the emitted YAML hashes structurally.
- The `publication_fetcher_spec.rb` is the integration test: it
  exercises CataloguePage + ProductPage + CrossLanguageLinker +
  PdfDownloader (with a pre-cached fixture PDF) + CoverPageParser end-to-end.

### Coverage targets

- `IalaFetcher::Docid` — every constructor × every accessor.
- `IalaFetcher::CataloguePage` — multi-page pagination, language cell
  parsing, empty category.
- `IalaFetcher::ProductPage` — present/missing optional fields,
  multi-language variants.
- `IalaFetcher::PublicationFetcher` — Work + Instance emission, hasInstance
  + instanceOf relations both directions.
- `IalaFetcher::Indexer` — clean-rebuild removes orphans, v1 + v2
  shapes, unparseable pubids skipped from v2 only.

### Acceptance

- [ ] `bundle exec rspec` passes with 0 failures.
- [ ] No use of `double`, `instance_double`, `class_double`.
- [ ] No use of `send` to call private methods.
- [ ] No use of `instance_variable_set` / `instance_variable_get`.
- [ ] No use of `respond_to?` for type checking.
- [ ] `spec/examples.txt` updated (rspec persistence).
