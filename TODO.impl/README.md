# Implementation priority order

P0 — blockers, do first (in this order):

- [00](00-pubid-iala.md) — Pubid::Iala in mn/pubid
- [01](01-bootstrap-layout.md) — Bootstrap relaton-data-iala layout
- [02](02-http-source-store.md) — Http, Source, YamlStore seams
- [03](03-docid.md) — Docid value object
- [04](04-catalogue-page.md) — CataloguePage listing scraper
- [05](05-product-page.md) — ProductPage detail scraper

P1 — depends on P0, ships the MVP:

- [06](06-cross-language-linker.md) — CrossLanguageLinker
- [07](07-pdf-downloader-ocr.md) — PdfDownloader + CoverPageOcr + CoverPageParser
- [08](08-publication-fetcher.md) — PublicationFetcher orchestrator
- [09](09-indexer-crawler-check-data.md) — Indexer + crawler + check_data
- [10](10-scrape-cli.md) — Thor CLI + binstub
- [12](12-specs.md) — Specs (land alongside each component)

P2 — refinement after MVP:

- [11](11-relaton-ext-model.md) — Finalize relaton ext model
- [13](13-ci-workflows.md) — CI workflows
- [14](14-readme-agents.md) — README + AGENTS.md
- [15](15-initial-scrape.md) — Initial scrape: standards + recommendations

P3 — completion:

- [16](16-full-scrape.md) — Full scrape
- [17](17-open-prs.md) — Open PRs
- [18](18-ocr-backfill.md) — OCR backfill for scanned PDFs
- [19](19-architecture-review.md) — Architecture review

## Critical path

```
00 ─┐
    ├─> 03 ─┐
01 ─┐      │
    ├─> 02 ─┼─> 04 ──┐
    │      │   05 ──┤
    │      │        ├─> 06 ──┐
    │      │        │        │
    │      │        │        ├─> 08 ─> 09 ─> 10
    │      │        │        │                  │
    │      │        │        │                  ├─> 13
    │      │        │        │                  ├─> 14
    │      │        │        │                  ├─> 15 ─> 16 ─> 17
    │      │        │        │
    │      │        │        └─> (specs land with each)
    │      │        │
    └─> 07 (needs 03 for URN) ──────────────────┘
```

## Time-budget sense check

- P0 (00–05): mostly mechanical porting of OIML patterns. ~1 day.
- P1 (06–10): the orchestrator + CLI + indexes. ~1 day.
- P2 (11–15): docs + first real scrape. ~0.5 day (scrape is bounded by
  HTTP throughput, not code).
- P3 (16–19): full scrape + PRs + review. ~0.5 day plus OCR wall-time.
