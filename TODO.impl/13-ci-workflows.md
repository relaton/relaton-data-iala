# 13 — CI workflows (reuse relaton/support)

**Priority:** P2 (gated by 09, 10).

## Why

Daily cron rebuilds + PR rspec + PR check_data. Mirror OIML exactly —
both workflows already exist in `relaton/support` and just need to be
referenced.

## Scope

### `.github/workflows/check_data.yml`

```yaml
name: check_data
on:
  push:
    branches: [ main ]
    tags: [ v* ]
  pull_request:
  workflow_dispatch:
jobs:
  check-data:
    uses: relaton/support/.github/workflows/check-data.yml@main
```

### `.github/workflows/crawler.yml`

```yaml
name: Crawler
on:
  push:
    branches: [ main ]
    tags: [ v* ]
  pull_request:
  schedule:
    - cron: '0 14 * * *'    # 14:00 UTC daily
  workflow_dispatch:
jobs:
  crawl:
    uses: relaton/support/.github/workflows/crawler.yml@main
```

### What these workflows do (for context)

- **crawler.yml** — runs `bundle install`, `bundle exec ruby crawler.rb`,
  zips `index-v1.yaml` → `index-v1.zip` (and v2 likewise), commits
  changed files back to the branch. On schedule, runs against `main`.
- **check_data.yml** — runs `bundle exec ruby check_data.rb` on every
  PR. Fails the PR if any YAML doesn't round-trip.

### Note on PDFs in CI

The cover-page OCR path requires a GLM API key (`Z_AI_API_KEY` secret).
CI should NOT run the OCR path by default — `--pdfs` is an opt-in CLI
flag, and the cron job runs without it. The cover-page metadata can be
captured locally by a maintainer and committed; CI then validates
round-trip only.

### Acceptance

- [ ] Both workflow files exist and reference `relaton/support`.
- [ ] A dry-run PR triggers `check_data.yml` green.
- [ ] After the first merge to `main`, the daily cron runs `crawler.yml`.
