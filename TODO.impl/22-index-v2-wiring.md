# 22 — Wire index-v2 to Pubid::Iala

**Priority:** P2 (blocked on `metanorma/pubid` PR merge).
**Status:** ❌ NOT DONE.

## Why

`index-v2.yaml` is currently empty (7 bytes — just `---\n...`) because
the pubid gem pinned in the Gemfile (`metanorma/pubid:rt-new-lutaml-model`)
doesn't yet have `Pubid::Iala`. The IALA flavor lives on
`metanorma/pubid:feat/iala-flavor` (PR open).

`index-v1.yaml` is fully populated (1736 entries) and unaffected.

## Scope

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
