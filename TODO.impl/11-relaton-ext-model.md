# 11 — Relaton ext model for IALA

**Priority:** P2 (gated by 08). Refinement after the dataset lands.

## Why

Relaton's `ext` block carries flavor-specific fields. IALA needs a small,
deliberate set — every field here is something the IALA catalogue or
cover page provides that the standard Relaton model can't express.

## Scope

### `ext` fields (on every record where the value is known)

| Field           | Type   | Example                          | Source |
|-----------------|--------|----------------------------------|--------|
| `doctype`       | object | `{ content: "standard" }`        | IALA type letter → doctype vocabulary |
| `flavor`        | string | `"iala"`                         | constant |
| `committee`     | string | `"ARM"` / `"ENG"` / `"DTEC"` / `"VTS"` | product page `Committee` row |
| `urn`           | string | `"urn:mrn:iala:pub:s1070:ed2.0"` | cover page; computed for works without cover |
| `webpage`       | string | `"https://www.iala.int/product/s1070/"` | instance only — the human-facing landing page |
| `normative`     | string | `"Nor"` / `"Inf"`                | catalogue "N/I" column (when known) |
| `supersedes`    | array  | docids                           | cover-page "Supersedes …" line, when present |

### What stays OUT of ext

Anything that fits the standard Relaton model goes on the top-level
object, not in `ext`:

- `title`, `docidentifier`, `date`, `contributor`, `language`, `script`,
  `status`, `copyright`, `relation`, `source` — all standard Relaton.
- `edition.content` — Relaton already models editions.

### Doctype vocabulary

```ruby
IalaFetcher::DOCTYPES = {
  "S" => "standard",
  "R" => "recommendation",
  "G" => "guideline",
  "M" => "manual",          # manuals (NAVGUIDE, VTS Manual, …) — no code
  "C" => "model-course",
  "X" => "report",          # reports & proceedings — no code
  "P" => "resolution",      # other-publications (Council resolutions etc.)
}.freeze
```

Manuals, reports, and resolutions don't carry a type letter on their
identifier (they have titles, not codes). Their `doctype` is set
explicitly by the fetcher from the category slug.

### Acceptance

- [ ] Every emitted YAML has `ext.flavor == "iala"`.
- [ ] Every emitted YAML has `ext.doctype.content` matching its type.
- [ ] Every instance YAML has `ext.webpage` populated.
- [ ] `ext.urn` is present on every record (computed for works without
      a cover-page URN).
- [ ] `check_data.rb` preserves every `ext.*` key through round-trip.
