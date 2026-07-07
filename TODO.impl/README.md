# Status of TODO.impl files (2026-07-08)

Legend: ✅ DONE · 🟡 PARTIAL · ❌ NOT DONE · 🪦 OBSOLETE

| File | Status | Notes |
|------|--------|-------|
| [00-pubid-iala.md](00-pubid-iala.md) | ✅ | PRs [metanorma/pubid#91](https://github.com/metanorma/pubid/pull/91) + [#92](https://github.com/metanorma/pubid/pull/92) merged into `rt-new-lutaml-model`. 30 specs passing. |
| [01-bootstrap-layout.md](01-bootstrap-layout.md) | ✅ | All layout in place. |
| [02-http-source-store.md](02-http-source-store.md) | ✅ | Http (NetHttp + Fake), Source, YamlStore. |
| [03-docid.md](03-docid.md) | ✅ | Docid handles typed codes + resolution codes + slug-derived ids. |
| [04-catalogue-page.md](04-catalogue-page.md) | ✅ | Pagination, row extraction, language cell, post_id. |
| [05-product-page.md](05-product-page.md) | ✅ | All fields parsed. |
| [06-cross-language-linker.md](06-cross-language-linker.md) | ✅ | Groups by `bare_code`. |
| [07-pdf-downloader-ocr.md](07-pdf-downloader-ocr.md) | ✅ | Full `--pdfs` pass run. 439 PDFs cached by PubID (e.g. `pdfs/s1070-2.0-e.pdf`), 1 GLM-OCR call exercised. |
| [08-publication-fetcher.md](08-publication-fetcher.md) | ✅ | Orchestrator works; 863 YAMLs emitted. |
| [09-indexer-crawler-check-data.md](09-indexer-crawler-check-data.md) | ✅ | Both indexes populated. `index-v2.yaml` has 3580 lines via `Pubid::Iala`. Zip artifacts committed. |
| [10-scrape-cli.md](10-scrape-cli.md) | ✅ | Thor CLI + binstub. |
| [11-relaton-ext-model.md](11-relaton-ext-model.md) | 🪦 | **OBSOLETE** — superseded by [20-relaton-iala-mono.md](20-relaton-iala-mono.md). |
| [12-specs.md](12-specs.md) | ✅ | 65 examples across 11 spec files; no doubles. |
| [13-ci-workflows.md](13-ci-workflows.md) | ✅ | Workflows reuse relaton/support. |
| [14-readme-agents.md](14-readme-agents.md) | ✅ | README.adoc, AGENTS.md, CLAUDE.md all written. |
| [15-initial-scrape.md](15-initial-scrape.md) | ✅ | Standards + recommendations scraped. |
| [16-full-scrape.md](16-full-scrape.md) | ✅ | 863 YAMLs across all 10 categories with PDF enrichment. |
| [17-open-prs.md](17-open-prs.md) | 🟡 | pubid PRs merged. relaton/relaton#20 and relaton/relaton-data-iala#1 still open. |
| [18-ocr-backfill.md](18-ocr-backfill.md) | 🟡 | OCR fallback path coded and exercised once (1 cache entry). Defensive — most covers were born-digital. |
| [19-architecture-review.md](19-architecture-review.md) | 🟡 | 3 of 5 original questions closed; 2 deferred. |

## New TODOs added after the initial plan

| File | Status | Notes |
|------|--------|-------|
| [20-relaton-iala-mono.md](20-relaton-iala-mono.md) | ✅ | IALA flavor in relaton v3 monorepo. Standalone repo archived. |
| [21-pdf-ocr-enrichment.md](21-pdf-ocr-enrichment.md) | ✅ | Full `--pdfs` pass run. 660/864 YAMLs carry URN (76%); rest are codeless. |
| [22-index-v2-wiring.md](22-index-v2-wiring.md) | ✅ | `index-v2.yaml` populated via `Pubid::Iala`. |
| [23-canonical-xml-specs.md](23-canonical-xml-specs.md) | ✅ | canon migration in IALA specs. |
| [24-missing-specs.md](24-missing-specs.md) | ✅ | PdfDownloader, CoverPageOcr, Indexer, Scrape specs added. |

## Critical remaining work

1. **relaton/relaton#20** still open — blocks flipping the Gemfile back to `branch: "main"`.
2. **relaton/relaton-data-iala#1** still open — the full dataset PR awaits review.
3. **Gemfile cleanup** — once relaton/relaton#20 merges, flip `gem "relaton"` from `branch: "feat/iala-flavor"` to `branch: "main"`.
4. **19-architecture-review** — close out remaining 2 questions after PRs land.
