# 10 — IalaFetcher::Scrape (Thor CLI) + exe/iala-fetch binstub

**Priority:** P1 (gated by 09).

## Why

Operators invoke the scraper via `bundle exec iala-fetch` (or just
`iala-fetch` once installed). The Thor CLI exposes the right level of
granularity: full scrape, narrow by category/language, opt into PDF
download + OCR, rebuild indexes.

## Scope

### `lib/iala_fetcher/scrape.rb`

```ruby
class IalaFetcher::Scrape < Thor
  default_task :fetch

  desc "fetch", "Fetch IALA publications into data/"
  method_option :type,      type: :string, repeatable: true
  method_option :language,  type: :string, repeatable: true
  method_option :pdfs,      type: :boolean, default: false
  method_option :data_dir,  type: :string,  default: "data"
  method_option :pdfs_dir,  type: :string,  default: "pdfs"
  def fetch
    # construct deps, run PublicationFetcher, optionally Indexer.
  end

  desc "index", "Rebuild index-v1.yaml + index-v2.yaml"
  def index
    load File.expand_path("../../crawler.rb", __dir__)
  end
end
```

### `exe/iala-fetch`

```ruby
#!/usr/bin/env ruby
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "iala_fetcher"
IalaFetcher::Scrape.start(ARGV)
```

### CLI surface

| Command                                     | Effect |
|---------------------------------------------|--------|
| `iala-fetch`                                | Full scrape, all categories × all available languages, no PDFs |
| `iala-fetch --type=standards`               | Just standards |
| `iala-fetch --type=recommendations --language=fr` | Just French recommendations |
| `iala-fetch --pdfs`                         | Also download PDFs + OCR cover pages |
| `iala-fetch --pdfs --type=standards`        | Same, scoped |
| `iala-fetch index`                          | Rebuild indexes only |

### Acceptance

- [ ] `bundle exec iala-fetch --help` lists every task.
- [ ] `bundle exec iala-fetch index` rebuilds indexes via `crawler.rb`.
- [ ] Unknown options produce Thor's standard "no such option" error,
      not a Ruby backtrace.
- [ ] Binstub works without bundler if the gem is installed (manual
      test; not in CI).
