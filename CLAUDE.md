# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Bibliographic dataset of IALA (International Organization for Marine Aids to
Navigation — formerly IALA AISM) publications, stored as Relaton YAML under
`data/`. The scraper lives in this repo (`lib/iala_fetcher/`); data is
consumed by `relaton-bib` directly via `Relaton::Bib::Item` (no
`relaton-iala` gem exists yet).

IALA publication categories, with their catalogue letter prefixes:

| Path segment under `/product-category/publications/` | Prefix | doctype          |
|------------------------------------------------------|--------|------------------|
| `standards`                                          | S      | standard         |
| `recommendations`                                    | R      | recommendation   |
| `guidelines`                                         | G      | guideline        |
| `manuals`                                            | —      | manual           |
| `model-courses`, `model-courses/level-1-…`, `model-courses/level-2-…`, `model-courses/vts-model-courses` | C | model-course |
| `reports-and-proceedings`                            | —      | report           |
| `other-publications`                                 | —      | resolution/other |

Numbered identifiers take the form `<Letter><4-digit>` (e.g., `S1070`,
`R0126`, `G1015`, `C0103-1`). Editions are dotted (`2.0`, `1.3`, `Ed 9.0`).
URN form printed on covers: `urn:mrn:iala:pub:s1070:ed2.0`.

## The big picture: iala.int is WooCommerce HTML

The site is a WordPress + WooCommerce store. Listing pages are server-rendered
HTML tables, one row per product, with the identifier in a `td.highlight`,
the title in an `<a class="woocommerce-LoopProduct-link">`, the date in the
last cell, and an optional language cell ("PDF: English", "PDF: French").
Pagination is `<base>/page/N/` (1-indexed; page 1 is the bare URL).

Product detail pages (`/product/<slug>/`) expose a `data` table with rows
for ID / Edition / Date / Revised Date / Committee, plus Format/Language
attributes and a Download link (`<a href="?download=true">`) that 200s the
PDF (no redirect — the server streams `application/pdf` directly).

Most products have **no abstract** in their HTML — the abstract is only on
the PDF cover page. The fetcher downloads each PDF and OCRs/extracts the
first page to recover title, edition, month/year, and URN. The
`reference-docs/Technical-documents-Catalogue-Ed-10.0-December-2025-03.02.2026.pdf`
catalogue is the canonical reference for cross-checking.

## Multilingual model

IALA publishes in six official languages. The website exposes them via
parallel category pages:

- `/product-category/publications/recommendations/` (English, default)
- `/product-category/publications/recommendations-french/`
- `/product-category/publications/recommendations-spanish/`
- Arabic/Chinese/Russian categories exist as URL paths but currently 404.

The **Work + Instance** model (mirrors `relaton-data-oiml`):

- **Work** (`data/s1070_2.0.yaml`) — abstract publication. Carries docid,
  titles in all available languages, contributor, status. **No `source`**.
  Links to instances via `relation: hasInstance`.
- **Instance** (`data/s1070_2.0_eng.yaml`, `…_fra.yaml`) — language-specific
  PDF. One `source` (the `?download=true` URL), one `title`, one `language`.
  Links back via `relation: instanceOf`.

The "instance ID" on the listing page carries a `:fr` / `:es` suffix (e.g.,
`R1016:fr`); the docid of an instance is `<Work docid> (<Lang letter>)`
matching the cover-page convention `R1016:ed2.0(F)`.

## Repo layout

```
data/                     # work + instance YAMLs (e.g. s1070_2.0.yaml, s1070_2.0_eng.yaml)
Gemfile                   # psych pin + relaton + pubid + thor + nokogiri + rspec
crawler.rb                # entry point → IalaFetcher::Indexer.build
check_data.rb             # round-trip validator, exit 1 on mismatch
exe/iala-fetch            # binstub ($LOAD_PATH + require "iala_fetcher")
lib/iala_fetcher.rb       # module + constants + autoload entries
lib/iala_fetcher/
  docid.rb                # IalaFetcher::Docid value object
  source.rb               # IalaFetcher::Source (.url, .iala, .local)
  http.rb                 # IalaFetcher::Http seam (NetHttp + Fake adapters)
  yaml_store.rb           # IalaFetcher::YamlStore (write, read, patch, exist?)
  catalogue_page.rb       # HTML listing → product summary records
  product_page.rb         # HTML detail page → product detail record
  cross_language_linker.rb# matches equivalent pages across language categories
  pdf_downloader.rb       # caches PDFs by URL hash under pdfs/
  cover_page_ocr.rb       # GLM-OCR wrapper for first-page extraction
  cover_page_parser.rb    # parses OCR/text output into structured fields
  publication_fetcher.rb  # orchestrates the above → emits work + instance YAMLs
  indexer.rb              # IalaFetcher::Indexer.build (clean-rebuild v1 + v2)
  scrape.rb               # Thor subclass (fetch + index tasks)
spec/iala_fetcher/        # rspec specs (no doubles — real instances)
TODO.impl/                # implementation roadmap (numbered files)
reference-docs/           # canonical catalogue PDF and other authoritative sources
pdfs/                     # gitignored PDF cache (cover pages + full PDFs)
index-v1.yaml             # generated, committed (flat string docid index)
index-v2.yaml             # generated, committed (structured pubid index)
```

## Architecture

All modules use Ruby `autoload` (defined in `lib/iala_fetcher.rb`). No
`require_relative` anywhere in `lib/`. The binstub adds `lib/` to
`$LOAD_PATH` and calls `require "iala_fetcher"`.

Dependency injection: fetchers accept `yaml_store:` and `http_backend:`
parameters. Tests install `IalaFetcher::Http::Fake` with fixture tables;
production uses `IalaFetcher::Http::NetHttp` (the default).

`IalaFetcher::YamlStore` owns all YAML I/O — encoding (UTF-8), location
resolution, idempotency, and `Relaton::Bib::Item` serialization. No
`File.write` exists outside `YamlStore`.

`IalaFetcher::Docid` is the single value object for IALA document
identifiers (catalogue form `S1070`, cover form with edition, URN
`urn:mrn:iala:pub:s1070:ed2.0`). All fetchers use it for id/docid/filename
derivation.

`IalaFetcher::Source` produces correctly-typed `source` hashes (`.url`,
`.iala`, `.local`) — prevents the "local path tagged as website" bug.

## Pubid::Iala (in mn/pubid)

IALA PubIDs are parsed by the `Pubid::Iala` flavor in `mn/pubid` (target
branch: `rt-new-lutaml-model`). The flavor follows the OIML/IHO pattern:
`Identifier`, `Identifiers::*` (one class per doctype), `Parser`
(parslet), `Builder`, `Renderer`, `UrnGenerator`, `UrnParser`. The
`index-v2.yaml` serializes identifiers via
`Pubid::Iala::Identifier#to_hash` and re-instantiates via
`Pubid::Iala::Identifier.from_hash`.

## Commands

```bash
bundle install
bundle exec iala-fetch                                # fetch all categories × all languages
bundle exec iala-fetch --type=standards               # narrow scope to one category
bundle exec iala-fetch --languages=en,fr              # narrow languages
bundle exec iala-fetch --pdfs                         # download PDFs + OCR cover pages
bundle exec iala-fetch --rebuild-index                # rebuild index-v1 + index-v2
bundle exec rspec spec/                               # run specs
bundle exec ruby crawler.rb                           # rebuild indexes only
bundle exec ruby check_data.rb                        # round-trip validate data/
```

## Crawler + check_data contracts

`crawler.rb` delegates to `IalaFetcher::Indexer.build`, which indexes every
`data/*.yaml` by its primary docid into two indexes via `Relaton::Index`:
`index-v1.yaml` (flat string docid → file) and `index-v2.yaml` (structured
pubid identifier → file, with `pubid_class: Pubid::Iala::Identifier`). It
calls `idx.remove_all` first so both indexes are **rebuilt from scratch**
each run. v1 output is sorted by filename; v2 is sorted by pubid. The
`relaton/support` crawler workflow zips each `index*.yaml` into
`index*.zip` and commits both.

`check_data.rb` round-trips every YAML through
`Relaton::Bib::Item.from_yaml` → `to_yaml` and diffs against the source.
Exit 1 on any byte mismatch. Custom IALA `ext` fields that relaton-bib
doesn't model are merged back before comparison (same pattern as OIML).

## Gemfile

```ruby
gem "psych", "~> 5.2.6"   # 5.3.0 breaks YAML round-trip
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"
gem "pubid",   git: "https://github.com/metanorma/pubid.git",
               branch: "rt-new-lutaml-model"   # pubid v2 with IALA support
gem "thor", "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false   # String#squish
```

HTTPS git sources so the GH Action can clone anonymously.

## Conventions

- **Always read/write YAML with `encoding: "UTF-8"`** — IALA titles contain
  accentuated French (é, è, à) and other multi-script text.
- **Pin `psych ~> 5.2.6`** — 5.3.0 silently breaks the round-trip.
- **GitHub Actions reuse `relaton/support` workflows** — do not write
  custom ones.
- **Never commit to `main`, never push tags.** All changes go through a PR.
- **No AI attribution** in commit messages or PR descriptions.
- **Strict fetches — no fallbacks.** When a map (`LANG_CODE`,
  `COMMITTEE_CODE`, `DOCTYPE`) is missing a key, `.fetch(key)` raises. A
  missing key means the map is incomplete; silent defaults produce
  malformed data.
- **Never use `double()` in specs** — instantiate real objects or use
  `Struct.new` for plain data.
- **Never use `require_relative`** in library code — Ruby `autoload`
  declared in the immediate parent namespace's file.
- **Never use `send` to call private methods, `instance_variable_set/get`,
  or `respond_to?` for type checking.**

## Implementation roadmap

See `TODO.impl/` for the numbered plan. Each file describes one work item
with concrete acceptance criteria.
