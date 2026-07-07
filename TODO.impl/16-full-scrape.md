# 16 — Full scrape: all categories

**Priority:** P3 (gated by 15).

## Why

Standards and recommendations are the priority, but the catalogue covers
seven categories. Run the full pipeline and emit every YAML.

## Scope

```bash
bundle exec iala-fetch                        # every category, every language, no PDFs
bundle exec iala-fetch --pdfs                 # download PDFs, OCR cover pages
bundle exec ruby check_data.rb
bundle exec ruby crawler.rb
```

### Categories to cover

| Category                                | Estimated count |
|-----------------------------------------|-----------------|
| standards                               | 7 |
| recommendations                         | ~50 (× 1–3 languages) |
| guidelines                              | ~200 |
| manuals                                 | ~6 |
| model-courses                           | ~16 |
| model-courses/level-1-aton-manager-courses | 5 |
| model-courses/level-2-technician-courses | ~40 (C2001-1 … C2011-3) |
| model-courses/vts-model-courses         | ~5 |
| reports-and-proceedings                 | ~80 |
| other-publications (resolutions etc.)   | ~30 |

### Acceptance

- [ ] Every category produces YAMLs that round-trip cleanly.
- [ ] Manual and report categories without a type-letter code get a
      synthetic `id` derived from slug (e.g., `navguide_9.0` for the
      NAVGUIDE manual).
- [ ] Resolutions from `other-publications` carry `ext.doctype.content
      = "resolution"` and the resolution number is preserved in
      `docidentifier.content`.
- [ ] Total data file count: ~500–800 YAMLs (rough estimate; refine
      after first run).
- [ ] `git diff` after a second `iala-fetch` run with no upstream
      changes is empty.
