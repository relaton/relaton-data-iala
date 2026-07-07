# 00 — Pubid::Iala in mn/pubid (rt-new-lutaml-model)

**Priority:** P0 (blocks all downstream tasks — `index-v2.yaml` and
`IalaFetcher::Docid` both depend on it).

**Repo:** `mn/pubid` (sibling at `/Users/mulgogi/src/mn/pubid`).
**Target branch:** `rt-new-lutaml-model`.
**PR branch (create):** `feat/iala-flavor` off `origin/rt-new-lutaml-model`.

## Why

Every IALA PubID (`S1070`, `R0126:ed2.0`, `urn:mrn:iala:pub:s1070:ed2.0`)
needs a structured, serialisable representation so the relaton index can
key on it, sort by it, and round-trip it through YAML. `mn/pubid` already
hosts flavors for OIML, IHO, ISO, IEC, etc. — IALA slots in next to them.

## Scope

Add a new `Pubid::Iala` flavor following the OIML/IHO pattern. Parse every
PubID shape that appears on the IALA website or cover pages.

### Identifier shapes to support

| Form                                   | Example                            | Notes |
|----------------------------------------|------------------------------------|-------|
| Bare code (catalogue / listing)        | `S1070`, `R0126`, `G1015`, `C0103` | Type letter + 4-digit number |
| Code with sub-part                     | `C0103-1`, `R0124-9-10`, `R0112-1` | Numeric suffix; ranges stay literal |
| Code with edition (cover)              | `S1070 Ed 2.0`, `R0126 Ed 2.0`     | `Ed` separator optional |
| Code with edition + language           | `R1016:ed2.0(F)`                   | Parens carry single-letter lang code |
| Code with date (legacy)                | `G1015:2001`                       | Year-only editions exist on older docs |
| URN (cover)                            | `urn:mrn:iala:pub:s1070:ed2.0`     | Round-trips via UrnGenerator/UrnParser |
| OGC-style MRN extension                | `urn:mrn:iala:pub:s1070:ed2.0:fr`  | Optional language segment |

### Files to create

```
lib/pubid/iala.rb
lib/pubid/iala/identifier.rb             # Pubid::Iala::Identifier < Pubid::Identifier
lib/pubid/iala/identifiers.rb            # autoload entries
lib/pubid/iala/identifiers/base.rb       # Identifiers::Base = Pubid::Iala::Identifier alias
lib/pubid/iala/identifiers/standard.rb
lib/pubid/iala/identifiers/recommendation.rb
lib/pubid/iala/identifiers/guideline.rb
lib/pubid/iala/identifiers/manual.rb
lib/pubid/iala/identifiers/model_course.rb
lib/pubid/iala/identifiers/report.rb
lib/pubid/iala/identifiers/resolution.rb    # for "other-publications" resolutions
lib/pubid/iala/parser.rb
lib/pubid/iala/builder.rb
lib/pubid/iala/renderer.rb
lib/pubid/iala/urn_generator.rb
lib/pubid/iala/urn_parser.rb
spec/pubid/iala/identifier_spec.rb
spec/pubid/iala/parser_spec.rb
spec/pubid/iala/renderer_spec.rb
spec/pubid/iala/urn_generator_spec.rb
spec/pubid/iala/urn_parser_spec.rb
spec/pubid/iala/roundtrip_spec.rb
```

### Identifier attributes

```ruby
attribute :publisher, :string, default: "IALA"
attribute :number,     :string    # "1070", "0126", "0103-1"
attribute :edition,    :string    # "2.0", "1.3", nil
attribute :year,       :string    # for legacy year-only editions
attribute :language,   :string    # "E", "F", "S", "C", "A", "R" (single-letter, OIML-style)
```

`number` keeps any sub-parts as part of the string. The parser captures
the type letter and routes to the right subclass via
`Pubid::Iala.locate_type(code)` (mirror OIML).

### Renderer output

- `S1070` → `"IALA S1070"`
- `S1070` with edition `2.0` → `"IALA S1070 Ed 2.0"`
- with language `F` → `"IALA S1070 Ed 2.0 (F)"`

### URN

- Generate: `urn:mrn:iala:pub:s1070:ed2.0` (lowercase type letter, `ed`
  prefix on edition, language appended as final segment when present).
- Parse: accept and round-trip the same form.

### Registration

At the bottom of `lib/pubid/iala.rb`:

```ruby
Pubid::Registry.register(:iala, Pubid::Iala)
```

### Acceptance

- [ ] `Pubid::Iala.parse("S1070").to_s == "IALA S1070"`
- [ ] `Pubid::Iala.parse("S1070 Ed 2.0").to_urn == "urn:mrn:iala:pub:s1070:ed2.0"`
- [ ] `Pubid::Iala.parse("urn:mrn:iala:pub:s1070:ed2.0").to_s == "IALA S1070 Ed 2.0"`
- [ ] `Pubid::Iala.parse("R1016:ed2.0(F)").language == "F"`
- [ ] Polymorphic round-trip: `Pubid::Iala::Identifier.from_hash(id.to_hash) == id`
- [ ] Specs pass under `bundle exec rspec spec/pubid/iala/`
- [ ] No `require_relative`, no `double()`, no `send` to private methods

### Out of scope

- Part-letter suffixes (IALA doesn't use ISO-style part letters).
- Joint publications (none observed in the catalogue).
