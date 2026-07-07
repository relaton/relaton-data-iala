# AGENTS.md

Compact briefing for OpenCode sessions working in `relaton-data-iala`.
Sibling repo of `relaton-data-oiml`, `relaton-data-iho`, `relaton-data-bipm`
under `/Users/mulgogi/src/relaton/`.

## What this repo is

Bibliographic dataset of IALA publications (Standards, Recommendations,
Guidelines, Manuals, Model Courses, Reports, Resolutions) stored as
Relaton YAML under `data/`. The scraper lives in this repo
(`lib/iala_fetcher/`); the dataset is consumed by relaton-bib via the
typed `Relaton::Iala::Item` shipped inside the unified relaton v3 gem.

## The big gotcha: iala.int is WooCommerce HTML

The site is WordPress + WooCommerce. Listing pages are server-rendered
HTML tables, one row per product. **NOT** a React/JSON SPA like oiml.org.

Listing URL pattern: `https://www.iala.int/product-category/publications/<slug>/page/N/`
(1-indexed). Each row is:

```html
<tr class="post-NNNNN product type-product product_cat-<slug> …">
  <td class="highlight"><strong>S1020</strong></td>     <!-- code -->
  <td><a class="woocommerce-LoopProduct-link" href=".../product/s1020/">Title</a></td>
  <td>03 June 2023</td>                                   <!-- date -->
  <td>PDF: English</td>                                   <!-- optional language cell -->
</tr>
```

Product detail pages expose Edition / Date / Revised Date / Committee
rows in a `data` table. The Download button (`?download=true`) streams
`application/pdf` directly (no redirect).

Most products have **no website-side abstract** — the abstract is on
the cover page. `IalaFetcher::CoverPageParser` extracts title/edition/
month-year/URN from `pdftotext -layout -l 1` output, with GLM-OCR as
fallback for scans.

## Category → language slug map

The 10 base categories each have an English entry. Recommendations also
have French, Spanish, Arabic, Chinese, Russian variants (Arabic, Chinese,
Russian currently 404 on the site but the URLs are wired).

```ruby
IalaFetcher::LANGUAGE_CATEGORIES = {
  "standards"                                  => "eng",
  "recommendations"                            => "eng",
  "guidelines"                                 => "eng",
  "manuals"                                    => "eng",
  "model-courses"                              => "eng",
  "model-courses/level-1-aton-manager-courses" => "eng",
  "model-courses/level-2-technician-courses"   => "eng",
  "model-courses/vts-model-courses"            => "eng",
  "reports-and-proceedings"                    => "eng",
  "other-publications"                         => "eng",
  "recommendations-french"                     => "fra",
  "recommendations-spanish"                    => "spa",
  "recommendation-arabic"                      => "ara",
  "recommendation-chinese"                     => "zho",
  "recommendation-russian"                     => "rus",
}
```

## Work + Instance model

IALA publishes the same Work in multiple languages. The linker groups
rows by **bare_code** (the code with all language suffixes stripped),
which unifies both translation patterns:

- **Modern translations**: one WooCommerce `post_id` is listed under
  multiple language categories (R1016 has one post_id, appears on
  English/French/Spanish listings).
- **Legacy translations**: each language is its own product with its own
  `post_id` (A12-01-E and A12-01-F are distinct products).

Work YAMLs carry no `source` (abstract Work has no PDF); each Instance
YAML carries the language-specific PDF.

## Identifier derivation

| Item              | `id`              | `docidentifier.content` |
|-------------------|-------------------|-------------------------|
| Work              | `S1070-2.0`       | `IALA S1070 Ed 2.0`     |
| English instance  | `S1070-2.0-E`     | `IALA S1070 Ed 2.0 (E)` |
| French instance   | `S1070-2.0-F`     | `IALA S1070 Ed 2.0 (F)` |
| Codeless report   | `report-on-…`     | `IALA report-on-…`      |
| Legacy resolution | `a12-01`          | `IALA A12-01`           |

Language code map (ISO 639-3 → IALA single-letter):

```
eng → E, fra → F, spa → S, zho → C, ara → A, rus → R
```

## Cover-page OCR

- Cache: `pdfs/` for PDFs (keyed by URL SHA1), `pdfs/ocr-cache/` for GLM
  results (keyed by URL+window SHA256).
- API key: `~/.zai-api-key` or `ENV["Z_AI_API_KEY"]`.
- `pdftotext -layout -l 1` is tried first; OCR is the fallback for scans.
- Endpoint: `POST https://api.z.ai/api/paas/v4/layout_parsing` with
  `model: glm-ocr`. 30-page windows, retry on 429 with exponential back-off.

## Repo layout

```
data/                     # work + instance YAMLs
lib/iala_fetcher.rb       # module + constants + autoload
lib/iala_fetcher/         # 13 component files
exe/iala-fetch            # binstub
crawler.rb                # rebuilds index-v1 + index-v2
check_data.rb             # round-trip validator
spec/iala_fetcher/        # rspec specs (no doubles, real instances)
spec/fixtures/iala/       # archived HTML + cover-page text
reference-docs/           # IALA Technical Documents Catalogue PDF
pdfs/                     # gitignored PDF cache
pdfs/ocr-cache/           # gitignored OCR markdown cache
TODO.impl/                # implementation roadmap (24 files)
index-v1.yaml             # generated, committed (string docid → file)
index-v2.yaml             # generated, committed (structured pubid → file)
```

## Architecture

- **Ruby autoload**, no `require_relative` in `lib/`. Each component
  loaded lazily via entries declared in `lib/iala_fetcher.rb`.
- **Http seam** (`IalaFetcher::Http`): NetHttp (default) or Fake (specs).
- **Source seam**: `.url` / `.iala` / `.local` constructors prevent the
  "local path tagged as website" class of bug.
- **YamlStore** owns all `File.write` in the data dir.
- **Docid** is the single value object for IALA identifiers — typed
  (S/R/G/M/C) + generic (resolution codes, slug-derived ids).

## Commands

```bash
bundle install
bundle exec ruby exe/iala-fetch                 # full scrape, no PDFs
bundle exec ruby exe/iala-fetch --type=standards
bundle exec ruby exe/iala-fetch --pdfs          # also OCR cover pages
bundle exec ruby exe/iala-fetch index           # rebuild indexes only
bundle exec rspec spec/                         # 63 examples
bundle exec ruby check_data.rb                  # round-trip validator
bundle exec ruby crawler.rb                     # rebuild indexes
```

## Crawler + check_data contracts

`crawler.rb` delegates to `IalaFetcher::Indexer.build`, which iterates
`data/*.yaml` and emits two indexes:

- `index-v1.yaml` — flat string docid → filename
- `index-v2.yaml` — structured `Pubid::Iala` identifier → filename

`index-v2.yaml` is **empty until the metanorma/pubid feat/iala-flavor
PR merges**. See TODO.impl/22-index-v2-wiring.md.

`check_data.rb` round-trips each YAML through `Relaton::Iala::Item.from_yaml`
→ `to_yaml`. Because IALA `ext` fields (`urn`, `webpage`, `committee`,
`normative`, `supersedes`) are typed attributes on `Relaton::Iala::Ext`
(shipped inside the unified relaton gem per relaton/relaton#20), they
round-trip natively — **no merge hack**.

## Gemfile

```ruby
gem "psych", "~> 5.2.6"   # 5.3.0 breaks YAML round-trip
gem "relaton", git: "https://github.com/relaton/relaton.git",
               branch: "feat/iala-flavor"   # flip to main after relaton/relaton#20 merges
gem "pubid",   git: "https://github.com/metanorma/pubid.git",
               branch: "rt-new-lutaml-model"
gem "thor", "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false
```

## Conventions

- **Always read/write YAML with `encoding: "UTF-8"`** — IALA titles
  contain accentuated French (é, è, à) and other multi-script text.
- **Pin `psych ~> 5.2.6`** — 5.3.0 silently breaks the round-trip.
- **GitHub Actions reuse `relaton/support` workflows** — don't write
  custom ones.
- **Never commit to `main`, never push tags, never add AI attribution.**
- **Strict fetches — no fallbacks.** When a map is missing a key,
  `.fetch(key)` raises. Silent defaults produce malformed data.
- **Never use `double()` in specs** — real instances or `Struct.new`.
- **Never use `require_relative`** in library code — Ruby autoload.
- **Never use `send` to private, `instance_variable_set/get`,
  `respond_to?` for type checking.**

## Reference files in sibling repos

- `relaton-data-oiml/lib/oiml_fetcher/` — architectural pattern source.
- `relaton-data-oiml/backfill/glm_ocr.rb` — GLM-OCR API template.
- `relaton/relaton/lib/relaton/oiml/` — Relaton::Iala flavor pattern source.
- `mn/pubid/lib/pubid/iala/` — Pubid::Iala flavor pattern source.

## TODOs

See `TODO.impl/` for the implementation roadmap (24 files, status
matrix in `TODO.impl/README.md`).
