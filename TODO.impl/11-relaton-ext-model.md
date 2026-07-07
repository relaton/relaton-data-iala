# 11 — Relaton ext model for IALA

**Status:** 🪦 OBSOLETE — superseded by [20-relaton-iala-mono.md](20-relaton-iala-mono.md).
**Priority:** N/A.

## Why this is obsolete

The original plan called for a per-repo Ext subclass with merge-back
hacks in `check_data.rb`. The user's 2026-07-07 directive moved the
IALA flavor into the relaton v3 monorepo, so the typed Ext lives at
`relaton/relaton:lib/relaton/iala/ext.rb` (mirroring `Relaton::Oiml`).

The acceptance criteria below are now satisfied by the monorepo flavor:

- Every emitted YAML has `ext.flavor == "iala"` ✓
- Every emitted YAML has `ext.doctype.content` ✓
- Every instance YAML has `ext.webpage` populated ✓ (when scraped)
- `ext.urn` is present where the cover page provided one ✓
  (full-dataset URN enrichment is TODO [21](21-pdf-ocr-enrichment.md))
- `check_data.rb` round-trips natively (no CUSTOM_EXT_KEYS merge hack) ✓

The doctype vocabulary moved from `IalaFetcher::DOCTYPES` (a constant in
the scraper) to `Relaton::Iala::Doctype::TYPES` (in the relaton gem).

---

## Original scope (for historical reference)

Relaton's `ext` block carries flavor-specific fields. IALA needs a small,
deliberate set — every field here is something the IALA catalogue or
cover page provides that the standard Relaton model can't express.

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

### Doctype vocabulary

```ruby
Relaton::Iala::Doctype::TYPES
# => ["standard", "recommendation", "guideline", "manual", "model-course", "report", "resolution"]
```
