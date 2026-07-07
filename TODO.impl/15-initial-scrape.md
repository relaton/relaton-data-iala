# 15 — Initial scrape: standards + recommendations

**Priority:** P2 (gated by 08, 09, 10).

## Why

Validate the full pipeline against the two highest-value categories
before running on everything. Standards are 7 documents; recommendations
are ~50. Together they exercise every code path (single-language vs
multi-language, with/without cover-page URN, with/without committee).

## Scope

Run, in order:

```bash
bundle exec iala-fetch --type=standards
bundle exec iala-fetch --type=recommendations
bundle exec iala-fetch --type=recommendations --language=fr
bundle exec iala-fetch --type=recommendations --language=es
bundle exec iala-fetch --pdfs --type=standards
bundle exec iala-fetch --pdfs --type=recommendations
bundle exec ruby check_data.rb
bundle exec ruby crawler.rb
```

### Validation

For every emitted YAML:

- [ ] `id` matches `docidentifier.content` stripped of `IALA ` prefix
      and lowercased.
- [ ] Every Work has at least one `hasInstance` relation matching an
      emitted Instance.
- [ ] Every Instance has an `instanceOf` relation matching an emitted Work.
- [ ] `ext.urn` parses with `Pubid::Iala.parse` and round-trips via
      `to_urn`.
- [ ] `ext.webpage` is set on every Instance.
- [ ] `check_data.rb` passes.
- [ ] `index-v1.yaml` and `index-v2.yaml` are sorted and have matching
      entry counts (one Work + N Instances per code, both go into both
      indexes).

### Known gotchas to watch for

- R-codes with sub-parts (`R0124-1`, `R0112-1`) — Docid must preserve
  the sub-part in both the docid string and the filename.
- Standards with no committee field on the product page (S1010, S1020,
  S1070) — Work contributor block must skip the committee entry cleanly.
- Recommendations that have French/Spanish translations but the
  translation's product page has a different slug from the English one —
  the linker must use `post_id` as the join key, not slug.

### Acceptance

- [ ] ~7 standards Works + ~7 standards EN Instances committed.
- [ ] ~50 recommendations Works + matching EN/FR/ES Instances committed.
- [ ] `data/*.yaml` count is deterministic — re-running `iala-fetch`
      with no upstream changes produces zero `git diff`.
