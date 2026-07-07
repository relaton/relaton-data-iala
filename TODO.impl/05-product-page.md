# 05 — IalaFetcher::ProductPage (HTML detail scraper)

**Priority:** P0 (gated by 02).

## Why

The listing page gives only code/title/date. The product detail page at
`/product/<slug>/` carries Edition, Revised Date, Committee, Format,
Language, and (sometimes) an abstract. We need a structured record for
the fetcher to feed into `IalaFetcher::Docid` and the YAML builders.

## Scope

### `lib/iala_fetcher/product_page.rb`

```ruby
class IalaFetcher::ProductPage
  Detail = Struct.new(
    :product_url, :post_id, :code, :title, :edition, :date, :revised_date,
    :committee, :format, :language, :abstract_html, :download_url,
    keyword_init: true
  )

  def initialize(url:, http_backend: IalaFetcher::Http.backend)
  def fetch            # returns Detail
end
```

### Field extraction

Parse the page with Nokogiri, then locate the `<div itemscope>` product
container.

| Field          | Selector / strategy |
|----------------|---------------------|
| `product_url`  | passed in |
| `post_id`      | digits of `class="post-NNNNN …"` on the itemscope div |
| `code`         | `td[itemprop=productID]` text |
| `title`        | `h1[itemprop=name]` text, squished |
| `edition`      | row whose `th` is "Edition", take `td` text |
| `date`         | row whose `th` is "Date", take `td` text |
| `revised_date` | row whose `th` is "Revised Date", take `td` text (optional) |
| `committee`    | row whose `th` is "Committee", take `td` text (optional) |
| `format`       | text following `<strong>Format: </strong>` (optional) |
| `language`     | text following `<strong>Language: </strong>` (optional) |
| `abstract_html`| inner HTML of the first `<div class="page">` block (optional; most products have none) |
| `download_url` | absolute URL built from the product URL + the `?download=true` query string on the `.btn` anchor |

The `data` table has variadic rows; iterate `<tr>` and match on the `th`
text rather than relying on positional indices.

### Acceptance

- [ ] `spec/iala_fetcher/product_page_spec.rb` parses a fixture
      (`spec/fixtures/iala/product_s1070.html` — archive a real page)
      and asserts every field.
- [ ] Missing optional fields don't raise; they stay `nil`.
- [ ] The HTML entity `&#038;` decodes correctly (Nokogiri handles this
      by default — assert it explicitly).
- [ ] No doubles.
