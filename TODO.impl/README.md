# Status of TODO.impl files (2026-07-07)

Legend: ✅ DONE · 🟡 PARTIAL · ❌ NOT DONE · 🪦 OBSOLETE

| File | Status | Notes |
|------|--------|-------|
| [00-pubid-iala.md](00-pubid-iala.md) | ✅ | 30 specs passing. PR open at `metanorma/pubid:feat/iala-flavor`. |
| [01-bootstrap-layout.md](01-bootstrap-layout.md) | ✅ | Gemfile, .rspec, .gitignore, exe/, spec/, .github/workflows all in place. |
| [02-http-source-store.md](02-http-source-store.md) | ✅ | Http (NetHttp + Fake), Source, YamlStore all written + spec'd. |
| [03-docid.md](03-docid.md) | ✅ | Docid written; **expanded** beyond original spec — also handles resolution codes (`GA01.13`) and slug-derived ids. |
| [04-catalogue-page.md](04-catalogue-page.md) | ✅ | Pagination, row extraction, language cell, post_id all working. |
| [05-product-page.md](05-product-page.md) | ✅ | All fields parsed; optional fields handled. |
| [06-cross-language-linker.md](06-cross-language-linker.md) | ✅ | **Rewritten** — groups by `bare_code` (not just `post_id`) so legacy `-E`/`-F` resolutions merge correctly. |
| [07-pdf-downloader-ocr.md](07-pdf-downloader-ocr.md) | 🟡 | Code written. Only 20 PDFs cached, 0 OCR cache — **full `--pdfs` pass not yet run**. |
| [08-publication-fetcher.md](08-publication-fetcher.md) | ✅ | Orchestrator works; scraped 863 YAMLs end-to-end. |
| [09-indexer-crawler-check-data.md](09-indexer-crawler-check-data.md) | 🟡 | Code works; `index-v1.yaml` populated. `index-v2.yaml` empty (pubid gem on `rt-new-lutaml-model` doesn't have IALA yet). `index-v1.zip` / `index-v2.zip` not yet generated (the `relaton/support` cron does this on first merge). |
| [10-scrape-cli.md](10-scrape-cli.md) | ✅ | Thor CLI + binstub work; --type / --pdfs / index tasks all wired. |
| [11-relaton-ext-model.md](11-relaton-ext-model.md) | 🪦 | **OBSOLETE** — superseded by [20-relaton-iala-mono.md](20-relaton-iala-mono.md). The Ext subclass now lives inside `relaton/relaton:lib/relaton/iala/ext.rb`. |
| [12-specs.md](12-specs.md) | 🟡 | 42 specs in data-iala + 4 in relaton-v3. **Missing**: PdfDownloader, CoverPageOcr, Indexer, Scrape specs. |
| [13-ci-workflows.md](13-ci-workflows.md) | ✅ | `.github/workflows/{check_data,crawler}.yml` written; reuse `relaton/support`. Not yet exercised (cron triggers after first merge to main). |
| [14-readme-agents.md](14-readme-agents.md) | ❌ | `README.adoc` and `AGENTS.md` not yet written. `CLAUDE.md` exists. |
| [15-initial-scrape.md](15-initial-scrape.md) | ✅ | Standards + recommendations both scraped. |
| [16-full-scrape.md](16-full-scrape.md) | ✅ | 863 YAMLs across all 10 categories. No `--pdfs` enrichment yet — see [21-pdf-ocr-enrichment.md](21-pdf-ocr-enrichment.md). |
| [17-open-prs.md](17-open-prs.md) | ✅ | 3 PRs open: `metanorma/pubid:feat/iala-flavor`, `relaton/relaton#20`, `relaton/relaton-data-iala#1`. None merged. |
| [18-ocr-backfill.md](18-ocr-backfill.md) | ❌ | OCR fallback path coded but never exercised. |
| [19-architecture-review.md](19-architecture-review.md) | 🟡 | Open questions still relevant; revisit after PRs merge. |

## New TODOs added after the initial plan

| File | Status | Notes |
|------|--------|-------|
| [20-relaton-iala-mono.md](20-relaton-iala-mono.md) | ✅ | Move IALA flavor from standalone gem into relaton v3 monorepo (per user 2026-07-07). Done; standalone repo archived. |
| [21-pdf-ocr-enrichment.md](21-pdf-ocr-enrichment.md) | ❌ | Run `--pdfs` on the full 863-file dataset to populate URN, edition-from-cover, committee-from-cover, and OCR any scanned PDFs. |
| [22-index-v2-wiring.md](22-index-v2-wiring.md) | ❌ | Wire index-v2 to `Pubid::Iala` once the `mn/pubid` PR merges; flip the Gemfile back to relaton/relaton:main. |
| [23-canonical-xml-specs.md](23-canonical-xml-specs.md) | ✅ | Replace `equivalent-xml` with `canon` in IALA specs (per user 2026-07-07). Done. |
| [24-missing-specs.md](24-missing-specs.md) | ❌ | Add specs for PdfDownloader, CoverPageOcr, Indexer, Scrape. |

## Critical remaining work

1. **PRs to merge**: `metanorma/pubid`, `relaton/relaton#20` — blockers for index-v2 and Gemfile cleanup.
2. **PDF/OCR enrichment** ([21](21-pdf-ocr-enrichment.md)) — captures URN, edition, committee from cover pages. Most current YAMLs lack URN.
3. **Missing specs** ([24](24-missing-specs.md)) — 4 components untested.
4. **README + AGENTS** ([14](14-readme-agents.md)) — the repo has no top-level docs yet.
