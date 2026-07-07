# 19 — Architecture review

**Priority:** P3 (gated by 16). Reflective — what to revisit after the
dataset lands.

## Open questions to revisit

### 1. Should IalaFetcher::Docid fold into Pubid::Iala::Identifier?

Today `Docid` is a thin wrapper: it adds `id`, `filename_stem`, and
`with_language` to `Pubid::Iala::Identifier`. After the dataset is
populated and the patterns stabilise, consider whether those methods
belong on `Pubid::Iala::Identifier` itself (with a `relaton:` keyword
arg or a separate `Relaton` mixin) so the wrapper can disappear.

**Why defer:** the right API shape isn't clear until we've seen 500+
identifiers round-trip. Premature consolidation would lock in a bad
shape.

### 2. Should the Work + Instance split be enforced by a typed model?

Today the work vs instance distinction is implicit: Works lack a
`source`, Instances carry `relation: instanceOf`. Relaton's typed
ext block could make this explicit (`ext.kind = "work"|"instance"`).
Consider after seeing whether downstream consumers (relaton-cli,
relaton-db) care.

### 3. CoverPageParser — regex vs structured grammar?

The current cover-page parser is line-based regex. If IALA changes its
cover layout, the parser breaks silently. A parslet grammar would be
more robust but adds complexity. Revisit if more than two layout
variants surface.

### 4. Identifier normalization for legacy codes

Some pre-2017 IALA codes use the legacy `R<3-digit>` form (`R100`,
`R101`) instead of `R<4-digit>` (`R0100`, `R0101`). The catalogue uses
4-digit; the website sometimes shows the legacy form. Confirm whether
both should be treated as the same identifier or kept distinct.

### 5. Manual and report records — synthetic codes?

Today manuals (`NAVGUIDE`, `VTS Manual`) and reports don't have type
codes. They get synthetic ids (`navguide_9.0`, `vts_manual_8.4`). This
makes their docids look unlike other IALA identifiers. Consider whether
a `M####` prefix should be minted for them.

## Triggers for revisiting

- New category or identifier shape appears on the website.
- Downstream consumer asks for a field we don't expose.
- Round-trip mismatch surfaces a custom-ext hole.
- Pubid::Iala gains capabilities that subsume Docid.

## Acceptance

- [ ] After full scrape, review the five questions and update
      TODO.impl/* or close them with a written decision.
