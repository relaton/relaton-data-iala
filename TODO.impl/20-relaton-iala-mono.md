# 20 — Relaton::Iala flavor in the v3 monorepo

**Priority:** P0 (was a hard user requirement on 2026-07-07).
**Status:** ✅ DONE — PR open at <https://github.com/relaton/relaton/pull/20>.

## Why

The user clarified that `relaton/relaton` v3.0.0.pre.alpha.1 is a monorepo
with every flavor (`Oiml`, `Iho`, `Iala`, etc.) under `lib/relaton/<flavor>/`.
The standalone `relaton-iala` gem was short-lived and has been **archived**
(<https://github.com/relaton/relaton-iala>).

## Scope (delivered)

Files added to `relaton/relaton` on branch `feat/iala-flavor`:

```
lib/relaton/iala.rb                  — module entry, 12 autoload entries
lib/relaton/iala/util.rb             — Util (logger)
lib/relaton/iala/doctype.rb          — Doctype vocabulary (7 types)
lib/relaton/iala/ext.rb              — Ext < Bib::Ext (urn, webpage, committee, normative, supersedes)
lib/relaton/iala/item_data.rb        — ItemData (empty subclass)
lib/relaton/iala/item_base.rb        — ItemBase for Relation's bibitem
lib/relaton/iala/item.rb             — Item < Bib::Item with typed Ext
lib/relaton/iala/relation.rb         — Relation < Bib::Relation
lib/relaton/iala/bibitem.rb          — Bibitem < Item
lib/relaton/iala/bibdata.rb          — Bibdata < Item
lib/relaton/iala/docidentifier.rb    — Docidentifier (optional Pubid::Iala)
lib/relaton/iala/bibliography.rb     — Bibliography fetcher (data-iala)
lib/relaton/iala/processor.rb        — relaton-cli Processor
spec/iala/relaton/iala/ext_spec.rb   — Ext round-trip (XML via canon)
spec/iala/relaton/iala/item_spec.rb  — Item round-trip
spec/iala/support/webmock.rb         — canon + webmock setup
```

Plus `autoload :Iala, "relaton/iala"` registered in `lib/relaton.rb`.

`relaton-data-iala/Gemfile` pins `gem "relaton", git: …, branch: "feat/iala-flavor"` until the PR merges, then flips back to `branch: "main"`.

## Conventions followed (per global rule)

- **Autoload, not `require_relative`** — all sub-files loaded via autoload entries declared in `lib/relaton/iala.rb`.
- **`canon` matcher, not `equivalent-xml`** — `be_xml_equivalent_to` in ext_spec.
- **No doubles in specs** — real `Relaton::Iala::Ext.new(...)` instances.

## Acceptance

- [x] `bundle exec rspec spec/iala/relaton/iala/` — 4 examples passing
- [x] Ext round-trips urn, webpage, committee, normative, supersedes through YAML and XML
- [x] Item uses the typed Ext natively
- [x] No `require_relative` in `lib/relaton/iala/**`
- [x] PR open at relaton/relaton#20

Replaces the now-obsolete [11-relaton-ext-model.md](11-relaton-ext-model.md).
