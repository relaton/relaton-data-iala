# 04 — IalaFetcher::CataloguePage (HTML listing scraper)

**Priority:** P0 (gated by 02).

## Why

The seven publication categories live at paginated URLs
`https://www.iala.int/product-category/publications/<slug>/page/N/`. Each
page is a WooCommerce table whose rows are products. We need an object
that, given a category slug, walks every page and yields
`CataloguePage::Row` records.

## Scope

### `lib/iala_fetcher/catalogue_page.rb`

```ruby
class IalaFetcher::CataloguePage
  Row = Struct.new(:post_id, :code, :title, :date, :language_cell, :product_url, keyword_init: true)

  def initialize(slug:, http_backend: IalaFetcher::Http.backend)
  def each_row              # enumerator, yields Row
  def pages                 # enumerator, yields [page_number, Nokogiri::Doc]
end
```

### Pagination strategy

- Fetch `<base>/<slug>/` (page 1).
- Look for `<a href="…/page/N/">` anchors in the pagination widget; take
  the max N.
- Iterate `1..max`, fetching each page; page 1 may already be cached.
- Stop early if a page returns no product rows (defensive — pagination
  links are sometimes stale).

### Row extraction

For each `<tr class="post-NNNNN product type-product …product_cat-<slug>…">`:

1. `post_id` — the trailing digits of the first `class` token `post-NNNNN`.
2. `code` — text of `td.highlight strong`. Strip any `:fr`/`:es` suffix
   into the language (only present on the French/Spanish category pages).
3. `title` — text of `td a.woocommerce-LoopProduct-link` (squish
   whitespace, decode entities via Nokogiri).
4. `date` — text of the third `td`. Parse with `Date.strptime` where
   possible; fall back to `Date.parse`.
5. `language_cell` — optional fourth `td` text ("PDF: English", "PDF:
   French"). `nil` when absent.
6. `product_url` — `href` of the `woocommerce-LoopProduct-link` anchor.

### Multi-language categories

`CataloguePage` is **category-agnostic**. It accepts any slug; the caller
decides which slug corresponds to which language. The same slug on the
`recommendations-french` page returns French-translated rows whose `code`
carries `:fr`. The `CrossLanguageLinker` (task 05) matches them to the
English rows by post_id.

### Acceptance

- [ ] `spec/iala_fetcher/catalogue_page_spec.rb` parses a fixture HTML
      (real archived listing under `spec/fixtures/iala/standards.html`)
      and asserts every expected `Row`.
- [ ] Pagination follows every `page/N` up to the discovered max.
- [ ] Empty categories yield zero rows, don't raise.
- [ ] No doubles — fixture HTML in `Http::Fake`.
