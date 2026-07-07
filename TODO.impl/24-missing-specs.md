# 24 — Missing specs (PdfDownloader, CoverPageOcr, Indexer, Scrape)

**Priority:** P2. **Status:** ❌ NOT DONE.

## Why

TODO 12 called for specs alongside each component. Current coverage:

| Component | Spec? | Examples |
|-----------|-------|----------|
| Http | ✓ | 5 (NetHttp via webmock + Fake) |
| Source | ✓ | 5 |
| YamlStore | ✓ | 3 |
| Docid | ✓ | 17 |
| CataloguePage | ✓ | 5 |
| ProductPage | ✓ | 3 |
| CrossLanguageLinker | ✓ | 6 |
| CoverPageParser | ✓ | 3 |
| PdfDownloader | ❌ | — |
| CoverPageOcr | ❌ | — |
| PublicationFetcher (integration) | ❌ | — |
| Indexer | ❌ | — |
| Scrape (CLI) | ❌ | — |

Total: 42 examples. The four missing components have ~10–15 examples
worth of behaviour to lock down.

## Scope

### `spec/iala_fetcher/pdf_downloader_spec.rb`

- Caches by URL SHA1 under `pdfs/`.
- Doesn't re-download when cached.
- `cached?` reflects filesystem state.
- Uses `IalaFetcher::Http::Fake` with a binary body fixture.

### `spec/iala_fetcher/cover_page_ocr_spec.rb`

- Reads API key from `ENV["Z_AI_API_KEY"]` (skip if unset).
- `ocr_first_page` returns cached markdown when present.
- Cache miss → posts to GLM endpoint (stub via webmock), writes cache.
- Retries on HTTP 429 (mock two 429s then a 200).

### `spec/iala_fetcher/indexer_spec.rb`

- `clean_index` removes existing entries.
- `add_pubid` warns and skips on Pubid::Iala parse failure.
- v1 always populated; v2 only when `pubid_class` resolves.
- Round-trip: rebuild from `data/*.yaml` produces a stable sorted index.

### `spec/iala_fetcher/scrape_spec.rb` (Thor CLI)

- `iala-fetch --help` lists every task.
- `iala-fetch index` loads crawler.rb.
- `iala-fetch --type=standards` restricts the fetcher (mock
  PublicationFetcher via dependency injection — no real network).

### Bonus: `spec/iala_fetcher/publication_fetcher_spec.rb`

End-to-end with `IalaFetcher::Http::Fake` and a small fixture set
(two product pages, one with FR translation). Asserts Work + Instance
emission, hasInstance + instanceOf relations, language attribution.

## Acceptance

- [ ] `bundle exec rspec spec/iala_fetcher/` runs ≥55 examples with 0 failures.
- [ ] No `double()` anywhere (use `Struct.new` for plain data, real classes for value objects).
- [ ] Coverage of PdfDownloader caching, CoverPageOcr retry, Indexer clean-rebuild, Scrape smoke.
