# 01 — Bootstrap relaton-data-iala layout

**Priority:** P0 (gated by nothing; gates all 02+ tasks).

## Why

The repo is empty besides `reference-docs/`. Before any fetcher code can
land we need the Gemfile, rspec config, binstub, autoload module file,
gitignore, and CI workflow stubs.

## Scope

Mirror `relaton-data-oiml`'s layout exactly so the `relaton/support`
workflows plug in without modification.

### Files to create

```
.gitignore                       # mirror OIML
.rspec                           # --format documentation --color --require spec_helper
Gemfile                          # psych pin + relaton + pubid + thor + nokogiri + rspec
Gemfile.lock                     # committed after first bundle install
exe/iala-fetch                   # binstub
lib/iala_fetcher.rb              # autoload module
spec/spec_helper.rb              # mirror OIML
.github/workflows/check_data.yml # reuses relaton/support
.github/workflows/crawler.yml    # reuses relaton/support
README.adoc                      # brief description + link to relaton.org
```

### Gemfile contents

Pin `psych ~> 5.2.6` (5.3.0 breaks YAML round-trip — same issue as OIML).
Pull `relaton` from `https://github.com/relaton/relaton.git` over HTTPS
(branch `main`) so the GH Action can clone anonymously. Pull `pubid`
from `https://github.com/metanorma/pubid.git` branch
`rt-new-lutaml-model`. Add `thor ~> 1.3`, `nokogiri`,
`net-http-persistent`, `activesupport` (for `String#squish`, lazy-required).

### `lib/iala_fetcher.rb` skeleton

Define the module, `BASE_URL`, `IALA_NAME`, `IALA_ABBR`, the `TYPES` map
(category slug → [prefix, doctype, language-defaults]), `LANG_CODE` map,
`DOCID_LANG_CODE` map, and autoload entries for every submodule. No
`require_relative` — Ruby `autoload` only.

### Acceptance

- [ ] `bundle install` succeeds with no warnings about lockfile mismatches
- [ ] `bundle exec rspec` runs (0 examples, 0 failures) before any spec exists
- [ ] `bundle exec iala-fetch` exits cleanly with a Thor "no task" message
- [ ] `bundle exec ruby -Ilib -e 'require "iala_fetcher"; p IalaFetcher'`
      prints `IalaFetcher`
- [ ] `.github/workflows/*.yml` reuse `relaton/support/.github/workflows/*`

### Out of scope

- Fetcher implementation (later tasks).
- Index files (committed only after first scrape).
