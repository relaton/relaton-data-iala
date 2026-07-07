# 26 — Comprehensive verification

**Priority:** P0 (final sanity check).
**Status:** 🟡 IN PROGRESS.

## Verification matrix

### Dataset coverage (as of 2026-07-08)

| Category | Works | EN | FR | ES | AR | ZH | RU |
|----------|-------|----|----|----|----|----|-----|
| standards (S) | 7 | 7 | — | — | — | — | — |
| recommendations (R) | 84 | 84 | 12 | 30 | — | — | — |
| guidelines (G) | 177 | 177 | — | — | — | — | — |
| manuals (M) | 4 | 4 | — | 1 | — | — | — |
| model-courses (C) | 42 | 42 | — | — | — | — | — |
| reports-and-proceedings (slug) | 89 | 89 | — | — | — | — | — |
| other-publications (A12/A13/GA01) | 8 | 8 | 1 | — | — | — | — |
| legacy (L2.x.x) | 3 | 3 | — | — | — | — | — |
| **Total Works** | **414** | | | | | | |
| **Total Instances** | | 408 | 12 | 30+1 | 0 | 0 | 0 |

Arabic / Chinese / Russian: IALA exposes URL paths for these
(`recommendation-arabic`, `recommendation-chinese`, `recommendation-russian`)
but they currently return HTTP 404. The scraper handles this gracefully
(`Http::BadStatus` → warn + empty array). When IALA activates these
categories, the scraper will pick them up without code changes.

### Field coverage

| Field | Works (414) | Instances (450) |
|-------|-------------|-----------------|
| `title` | 100% | 100% |
| `docidentifier` (primary) | 100% | 100% |
| `date.published` | 100% | 100% |
| `contributor` (publisher) | 100% | 100% |
| `contributor` (committee) | ~58% | ~58% |
| `language` | 100% | 100% |
| `script` | 100% | 100% |
| `status.stage` | 100% | 100% |
| `copyright` | 100% | 100% |
| `relation` (hasInstance / instanceOf) | 100% | 100% |
| `source` (PDF URL) | — | 100% |
| `ext.doctype` | 100% | 100% |
| `ext.flavor` | 100% | 100% |
| `ext.urn` | 75% (typed codes) | 77% |
| `ext.webpage` | 100% (English product page) | 100% |
| `ext.committee` | ~58% (only Recommendations/Guidelines/ModelCourses have it) | ~58% |
| `abstract` | ~2% (only 3 Standards) | ~2% |

### Component coverage

| Component | Spec | Examples |
|-----------|------|----------|
| Http | ✓ | 5 |
| Source | ✓ | 5 |
| YamlStore | ✓ | 3 |
| Docid | ✓ | 17 |
| CataloguePage | ✓ | 5 |
| ProductPage | ✓ | 3 |
| CrossLanguageLinker | ✓ | 6 |
| CoverPageParser | ✓ | 3 |
| PdfDownloader | ✓ | 5 |
| CoverPageOcr | ✓ | 6 |
| Indexer | ✓ | 5 (1 pending) |
| Scrape (Thor) | ✓ | 5 |
| PublicationFetcher (integration) | ✓ | 6 |
| **Total** | | **71 examples** |

### Indexes

- `index-v1.yaml`: string docid → file (1738 lines, populated)
- `index-v2.yaml`: structured Pubid::Iala → file (3580 lines, populated)
- `index-v1.zip`, `index-v2.zip`: committed for offline use

### Pipeline status

- [x] Scraper covers all 10 IALA categories + subcategories
- [x] Pagination walks every page (`<base>/page/N/` for N in 1..max)
- [x] Multi-language linking groups by `bare_code` (handles both modern
      post_id-shared and legacy separate-post_id patterns)
- [x] Cover-page text via `pdftotext`, GLM-OCR fallback for scans
- [x] URN populated where the cover page provides one
- [x] Abstracts captured for Standards
- [x] ext.webpage on both Works and Instances
- [x] Indexes rebuilt; check_data passes
- [x] 71 specs, 0 failures, no doubles, no require_relative in lib/

## Open items

1. **relaton/relaton#20** still open — Gemfile cleanup blocked.
2. **relaton/relaton-data-iala#1** still open — full dataset PR.
3. Some PDFs hit GLM's 50MB limit (warned and skipped — cover fields absent on those records).
4. Codeless reports (89 docs) don't have URN by design.
5. Re-scrape in progress to pick up the Work-filename bugfix (was `s1070.yaml`, will become `s1070-2.0.yaml`).
