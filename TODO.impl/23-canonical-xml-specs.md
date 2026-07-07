# 23 — Canonical XML specs (canon, not equivalent-xml)

**Priority:** P2. **Status:** ✅ DONE.

## Why

Per the user's 2026-07-07 directive: replace `equivalent-xml` with
`canon` (the Lutaml canonical-comparison gem) in all specs. `equivalent-xml`
has known shortcomings with whitespace and attribute ordering; `canon`
provides `be_xml_equivalent_to`, `be_equivalent_to`, `be_yaml_equivalent_to`
matchers backed by Nokogiri canonicalisation.

## Scope (delivered)

- `relaton/relaton-v3/spec/iala/support/equivalent_xml.rb` — **deleted**.
- `relaton/relaton-v3/spec/iala/support/webmock.rb` — now requires `canon`.
- `relaton/relaton-v3/spec/iala/relaton/iala/ext_spec.rb` — XML assertion
  switched from `expect(xml).to include` to
  `expect(...).to be_xml_equivalent_to(...)`.
- `relaton/relaton-v3/Gemfile` — added `gem "canon"` (alongside
  `equivalent-xml`, which other flavor suites still use).

## Acceptance

- [x] IALA ext_spec uses `be_xml_equivalent_to`
- [x] No `equivalent-xml` references in `spec/iala/`
- [x] All 4 IALA specs still pass

## Open question

Should the same migration happen for the other flavor suites (OIML, IHO,
CIE, etc.)? They still use `equivalent-xml`. The user's directive was
"in all specs" — broader migration is a separate PR per flavor.
