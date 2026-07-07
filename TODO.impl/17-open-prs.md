# 17 — Open PRs (pubid + relaton + relaton-data-iala)

**Status:** ✅ DONE — 3 PRs open (none merged).
**Priority:** P3.

## Current state (2026-07-07)

| PR | Repo | Status |
|----|------|--------|
| feat/iala-flavor → rt-new-lutaml-model | metanorma/pubid | open |
| feat/iala-flavor → main | relaton/relaton (#20) | open |
| feat/scraper-bootstrap → main | relaton/relaton-data-iala (#1) | open |

The standalone `relaton/relaton-iala` repo (was PR #1 there) is archived.

## Why

Two repos, two PRs. Neither merges without the other being mergeable
(relaton-data-iala's Gemfile pins pubid's `rt-new-lutaml-model` branch).

## PR 1 — pubid: feat/iala-flavor → rt-new-lutaml-model

**Repo:** `metanorma/pubid`.
**Source branch:** `feat/iala-flavor` (cut from `origin/rt-new-lutaml-model`).
**Target branch:** `rt-new-lutaml-model`.

### Title

```
feat(iala): add Pubid::Iala flavor
```

### Body sections

- Summary (one paragraph: new Pubid::Iala flavor for IALA PubIDs).
- Identifier shapes supported (table).
- Files added (list).
- Spec coverage (counts).
- Out of scope (joint publications, part-letter suffixes).

## PR 2 — relaton-data-iala: feat/scraper → main

**Repo:** `relaton/relaton-data-iala`.
**Source branch:** `feat/scraper`.
**Target branch:** `main`.

### Title

```
feat: bootstrap IALA scraper + initial dataset
```

### Body sections

- Summary (one paragraph).
- Architecture summary (link to CLAUDE.md).
- Dataset counts (per category).
- Test plan (rspec + check_data).
- Depends on: pubid PR #N (link).

### Sequence

1. Push `feat/iala-flavor` to pubid. Open PR. **Do not merge.**
2. Push `feat/scraper` to relaton-data-iala. Open PR. **Do not merge.**
3. Wait for user review on both.
4. After pubid PR merges and `rt-new-lutaml-model` is rebased, switch
   relaton-data-iala's Gemfile to track `rt-new-lutaml-model` (no
   branch change needed) and update `Gemfile.lock`.
5. Merge relaton-data-iala PR after pubid is merged or via feature
   branch ref.

### Hard rules

- **Never commit to main.** Create branches.
- **Never push tags.**
- **Never push to main.**
- **Never add `Co-authored-by` AI trailers.** Commit author is the
  user; AI is a tool, not a co-author.
- **Never force-push without confirmation.**

### Acceptance

- [ ] PR 1 open against `rt-new-lutaml-model` with all CI green.
- [ ] PR 2 open against `main` with all CI green.
- [ ] Neither PR auto-merges; both await user review.
