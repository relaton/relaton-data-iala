# 14 — Documentation: README.adoc + AGENTS.md

**Priority:** P2 (gated by 09).

## Why

The repo needs a README for end users and an AGENTS.md for future Claude
sessions. Both mirror the OIML siblings.

## Scope

### `README.adoc`

Brief overview:

- What the dataset is (Relaton YAML for IALA publications).
- How to install (`bundle install`).
- How to scrape (`bundle exec iala-fetch`).
- How to consume (via `relaton` CLI or `Relaton::Db`).
- Link to `relaton.org` for general docs.
- License (MIT, matching other relaton-data-* repos).

### `AGENTS.md`

Compact briefing for future Claude sessions — mirrors OIML's AGENTS.md.
Sections:

- **What this repo is** — short version of CLAUDE.md's "What this repo is".
- **The big gotcha: iala.int is WooCommerce HTML** — listing vs product
  page, pagination, language categories that 404 today.
- **Work + instance model** — one Work per code, one Instance per
  language, relation types.
- **Identifier derivation** — table of (id, docid, filename) for works
  and instances.
- **Cover-page OCR** — when needed, where the cache lives, where the
  API key is read from.
- **Repo layout** — short tree.
- **Architecture** — autoload, Http/Source/YamlStore seams, Docid
  wrapping Pubid::Iala.
- **Commands** — bundle exec lines.
- **Crawler + check_data contracts** — what rebuilds what, byte-stable
  invariants.
- **Gemfile** — pin rationale.
- **Strict fetches — no fallbacks** — `.fetch(key)` rule.
- **Conventions** — UTF-8, no main commits, no AI attribution, no
  doubles in specs.

### Acceptance

- [ ] `README.adoc` exists, < 100 lines, builds clean.
- [ ] `AGENTS.md` exists, mirrors OIML AGENTS.md structure.
- [ ] Both reference the TODO.impl/ files for ongoing work.
