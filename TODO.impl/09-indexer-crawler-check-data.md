# 09 — IalaFetcher::Indexer + crawler.rb + check_data.rb

**Status:** 🟡 PARTIAL — code complete, indexes committed but v2 empty.
**Priority:** P1.

## Current state (2026-07-07)

- `lib/iala_fetcher/indexer.rb` ✅ — clean-rebuild, v1+v2 split, pubid_class resolved lazily.
- `crawler.rb` ✅ — invokes `IalaFetcher::Indexer.build`.
- `check_data.rb` ✅ — uses `Relaton::Iala::Item` so ext fields round-trip natively (no merge hack needed after the [monorepo merge](20-relaton-iala-mono.md)).
- `index-v1.yaml` ✅ — 1736 entries, sorted.
- `index-v2.yaml` 🟡 — 7 bytes (`---\n...`); empty because `metanorma/pubid:rt-new-lutaml-model` doesn't have IALA yet. Tracked in [22](22-index-v2-wiring.md).
- `index-v1.zip` / `index-v2.zip` ❌ — not generated. The `relaton/support` crawler workflow will create these on first merge to `main`.

## Why

The relaton-db lookup pipeline needs two indexes: a flat
`index-v1.yaml` (string docid → filename) for legacy callers and a
structured `index-v2.yaml` (`Pubid::Iala` identifier → filename) for
typed lookups. The crawler rebuilds both daily; `check_data.rb` is the
last line of defense against YAML round-trip regressions.

## Scope

### `lib/iala_fetcher/indexer.rb`

Mirror `OimlFetcher::Indexer` exactly except for the pubid class.

```ruby
module IalaFetcher::Indexer
  module_function

  def build(data_dir:, index_file:, index_v2_file: nil)
    idx  = clean_index(file: index_file)
    idx2 = structured_index(index_v2_file)
    # … iterate data/*.yaml, add_or_update on both indexes, save.
  end
end
```

- `clean_index` calls `Relaton::Index.find_or_create :IALA, file:,
  pubid_class:` then `idx.remove_all` so old entries don't linger.
- `structured_index` lazy-loads `pubid` and instantiates with
  `pubid_class: Pubid::Iala::Identifier`.
- A docid pubid can't parse → warn and skip from v2 only; never drops
  out of v1.

### `crawler.rb`

```ruby
#!/usr/bin/env ruby
require "bundler"
require "relaton/index"
require "iala_fetcher"

IalaFetcher::Indexer.build(
  data_dir: "data",
  index_file: "index-v1.yaml",
  index_v2_file: "index-v2.yaml",
)
```

The `relaton/support` crawler workflow then zips each `index*.yaml` into
`index*.zip` and commits both.

### `check_data.rb`

Mirror OIML. Round-trip every YAML through
`Relaton::Bib::Item.from_yaml` → `to_yaml`; diff against source. Exit 1
on any mismatch or missing primary docidentifier.

Custom IALA `ext` fields that relaton-bib doesn't model (`urn`,
`webpage`, `committee`, `normative`) get merged back before comparison
(same pattern as OIML's `scope` / `quantity` / etc.).

### Acceptance

- [ ] `bundle exec ruby crawler.rb` regenerates both indexes from
      `data/*.yaml`.
- [ ] `bundle exec ruby check_data.rb` exits 0 with a full data set.
- [ ] `index-v1.yaml` is sorted by filename.
- [ ] `index-v2.yaml` entries are sorted by pubid.
- [ ] `index-v1.zip` and `index-v2.zip` round-trip with the YAMLs
      (`unzip -p index-v1.zip` matches `index-v1.yaml`).
- [ ] No doubles in `spec/iala_fetcher/indexer_spec.rb`.
