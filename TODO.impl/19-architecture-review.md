# 19 — Architecture review

**Status:** 🟡 PARTIAL — questions still open; some resolved by the scrape.
**Priority:** P3.

## Resolved by the full scrape (2026-07-07)

### 1. Should IalaFetcher::Docid fold into Pubid::Iala::Identifier?

**Partially answered.** `IalaFetcher::Docid` is no longer "thin" — it
now handles typed codes (S/R/G/M/C), resolution codes (`GA01.13`), and
slug-derived ids (codeless reports). Pubid::Iala only handles the typed
subset. Folding would require Pubid::Iala to grow the generic + slug
paths, which doesn't fit its parser model. **Decision: keep `Docid` as a
separate value object; have it delegate to `Pubid::Iala.parse` only for
URN generation when the code is typed.**

### 4. Legacy 3-digit codes

**Not seen in the scrape.** All recommendation codes on the current
site are 4-digit (`R0101`-`R1027`). The legacy `R100`/`R101` form is
not in the dataset. **Close as not-applicable until such a code surfaces.**

### 5. Manual and report records — synthetic codes?

**Resolved by adoption of slug-derived ids.** Manuals (`M0001`-`M0004`)
now have proper M codes on the site. Reports and codeless items use
their URL slug as the natural key (e.g. `report-on-the-workshop-on-…`).
**Decision: no synthetic codes — slugs are stable and human-readable.**

## Still open

### 2. Should the Work + Instance split be enforced by a typed model?

Today the work vs instance distinction is implicit: Works lack a
`source`, Instances carry `relation: instanceOf`. Relaton's typed ext
block could make this explicit. Defer until downstream consumers
(relaton-cli, relaton-db) signal they need it.

### 3. CoverPageParser — regex vs structured grammar?

Current parser is line-based regex. The full `--pdfs` pass (TODO [21](21-pdf-ocr-enrichment.md))
will surface any layout variants. If more than two variants appear,
switch to a parslet grammar.

## New questions (added 2026-07-07)

### 6. Should `Relaton::Iala` have per-document-type Item subclasses?

The pubid flavor has 7 classes (`Identifiers::Standard`, `Recommendation`,
`Guideline`, `Manual`, `ModelCourse`, `Report`, `Resolution`). The
relaton practice across all v3 flavors is **one `Item` class with
doctype on `Ext`** (OIML, IHO, CIE all do this). **Decision: keep the
single `Relaton::Iala::Item` — the bibliographic shape is uniform across
doctypes, and splitting would force lutaml polymorphic mapping per
subclass for zero benefit.**

### 7. Should the data scraper emit `Relaton::Iala::Item` or `Relaton::Bib::Item`?

Currently emits hash literals fed through `Relaton::Iala::Item.from_hash`
via `IalaFetcher::YamlStore#write`. This is correct. **No change.**

## Acceptance

- [x] After full scrape, review the five questions — done (3 closed, 2 deferred).
- [x] Capture new questions surfaced during the work — done (questions 6, 7 added).
