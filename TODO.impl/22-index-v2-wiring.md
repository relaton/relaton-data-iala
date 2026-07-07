# 22 — Wire index-v2 to Pubid::Iala

**Priority:** P2.
**Status:** ✅ DONE.

## Current state (2026-07-08)

- pubid PRs [#91](https://github.com/metanorma/pubid/pull/91) + [#92](https://github.com/metanorma/pubid/pull/92) merged into `rt-new-lutaml-model`.
- `IalaFetcher::Indexer.resolve_pubid_class` now returns `Pubid::Iala::Identifier`.
- `index-v2.yaml`: **3580 lines** (was 7 — empty), with each entry's `:id` a polymorphic `Pubid::Iala::*` instance.
- `index-v1.yaml`: 1738 lines (string docid → file), unchanged.
- `index-v1.zip` / `index-v2.zip`: generated and committed (relaton/support will regenerate in CI).
- Codeless items (slug-derived ids for ~89 reports/workshops) are warned and skipped from v2 only — they don't fit Pubid::Iala's typed grammar. This is correct.

## Why

### Step 1 — Land the pubid PR

Wait for `metanorma/pubid` maintainers to merge `feat/iala-flavor` into
`rt-new-lutaml-model`. The branch then carries `Pubid::Iala::Identifier`.

### Step 2 — Verify pubid in the data-iala bundle

```bash
bundle exec ruby -Ilib -e 'require "pubid/iala"; p Pubid::Iala.parse("S1070")'
```

Should print a `Pubid::Iala::Identifiers::Standard` instance, not raise.

### Step 3 — Re-run the indexer

```bash
bundle exec ruby crawler.rb
```

`IalaFetcher::Indexer#resolve_pubid_class` will now return
`Pubid::Iala::Identifier`, and `add_pubid` will route each docid through
`Pubid::Iala.parse`. Failures are warned and skipped from v2 only (never
drop from v1).

### Step 4 — Commit `index-v2.yaml` and `index-v2.zip`

The `relaton/support` crawler workflow zips each `index*.yaml` and
commits both. Local regeneration:

```bash
zip index-v1.zip index-v1.yaml
zip index-v2.zip index-v2.yaml
```

## Acceptance

- [ ] `index-v2.yaml` has the same entry count as `index-v1.yaml`.
- [ ] Each entry's `:id` is a `Pubid::Iala::Identifier` (polymorphic
      `_type` discriminator present).
- [ ] `index-v2.zip` round-trips: `unzip -p index-v2.zip` matches `index-v2.yaml` byte-for-byte.
- [ ] Unparseable docids (legacy `A12-01`, slug-derived report ids) are warned and skipped from v2 only.
