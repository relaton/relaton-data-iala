# 06 — IalaFetcher::CrossLanguageLinker

**Priority:** P1 (gated by 04).

## Why

IALA publishes the same Work in multiple languages. Each language has its
own category slug (`/recommendations/`, `/recommendations-french/`,
`/recommendations-spanish/`) but the underlying WordPress `post_id` is
the same. The linker matches rows across categories so the fetcher emits
one Work with N Instances rather than N unrelated records.

## Scope

### `lib/iala_fetcher/cross_language_linker.rb`

```ruby
class IalaFetcher::CrossLanguageLinker
  LANGUAGE_FOR_CATEGORY = {
    "recommendations"           => "eng",
    "recommendations-french"    => "fra",
    "recommendations-spanish"   => "spa",
    "recommendation-arabic"     => "ara",
    "recommendation-chinese"    => "zho",
    "recommendation-russian"    => "rus",
    "guidelines"                => "eng",   # only English exists today
    "standards"                 => "eng",
    "manuals"                   => "eng",
    # … etc, one entry per (category, language) pair that exists
  }.freeze

  def initialize(scraped_rows_by_category)   # hash { slug => [CataloguePage::Row, …] }
  def groups                                 # enumerator of Group structs
end

Group = Struct.new(:work_code, :instances_by_language, keyword_init: true)
# instances_by_language: { "eng" => Row, "fra" => Row, "spa" => Row, … }
```

### Matching algorithm

1. Bucket rows by their WordPress `post_id`.
2. Within each bucket, assert that all rows agree on `code` modulo the
   language suffix. If they disagree, warn and keep the English version
   as authoritative.
3. Emit one `Group` per bucket, keyed by the **bare code** (e.g. `R1016`).
   The Group holds one Row per language.

### Why post_id is the right key

WordPress reuses the same post across translations of a WooCommerce
product. The English `/product/r1016-…/` and French
`/product/r1016-aides-…/` pages share the same `post-NNNNN` even though
their slugs differ. The post_id is the only stable join key.

### Acceptance

- [ ] `spec/iala_fetcher/cross_language_linker_spec.rb` constructs
      several `Row` instances with the same post_id but different
      languages, asserts the linker emits one Group with N instances.
- [ ] A post_id that appears only in English yields a single-instance
      Group.
- [ ] Conflicting codes within a bucket warn but don't crash; the
      English code wins.
- [ ] No doubles.
