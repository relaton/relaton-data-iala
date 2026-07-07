# 07 — IalaFetcher::PdfDownloader + CoverPageOcr

**Priority:** P1 (gated by 02, 03). **Required for full bibliographic
encoding** — most products have no website-side abstract, so the cover
page is the only source for: title, edition, month/year, URN, and
sometimes committee.

## Why

The PDF `?download=true` endpoint streams `application/pdf` directly (no
redirect). For each Work we want to:

1. Download the PDF once (cache by URL SHA1 under `pdfs/`).
2. Extract page 1 as text. If the PDF has a text layer, use `pdftotext
   -layout -l 1`. If it's scanned (no text layer), fall back to GLM-OCR.
3. Parse the cover-page text into structured fields.

## Scope

### `lib/iala_fetcher/pdf_downloader.rb`

```ruby
class IalaFetcher::PdfDownloader
  def initialize(cache_dir: "pdfs", http_backend: IalaFetcher::Http.backend)
  def fetch(url)                  # returns local path; downloads if not cached
  def cached?(url)
end
```

- Cache filename: `pdfs/<sha1(url)>.<ext>` where ext is `pdf`.
- The directory is gitignored.
- Re-uses `IalaFetcher::Http.backend.get(url)` for the body.

### `lib/iala_fetcher/cover_page_ocr.rb`

Mirror `relaton-data-oiml/backfill/glm_ocr.rb` but adapt it to be a
maintained library component, not a backfill script.

```ruby
class IalaFetcher::CoverPageOcr
  ENDPOINT = URI("https://api.z.ai/api/paas/v4/layout_parsing").freeze
  PAGES_PER_CHUNK = 30

  def initialize(api_key: self.class.read_api_key, cache_dir: "pdfs/ocr-cache")
  def ocr_first_page(local_pdf_path)   # returns markdown string for page 1
  def self.read_api_key                # ~/.zai-api-key or ENV["Z_AI_API_KEY"]
end
```

- Same retry/back-off strategy as the OIML script (429 → exponential
  back-off, max 5 attempts).
- Same cache (per (url, page-window) SHA1).
- Only ever OCRs page 1 — that's all we need for bibliographic data.

### `lib/iala_fetcher/cover_page_parser.rb`

```ruby
class IalaFetcher::CoverPageParser
  Result = Struct.new(
    :label,           # "IALA STANDARD" / "IALA RECOMMENDATION" / etc.
    :code,            # "S1070"
    :title,           # "Information Services"
    :edition,         # "2.0"
    :month_year,      # "June 2023"
    :urn,             # "urn:mrn:iala:pub:s1070:ed2.0"
    keyword_init: true
  )

  def self.parse(text)              # returns Result or raises ArgumentError
end
```

Cover-page layout (verified against S1020, S1070):

```
IALA STANDARD

S1070
INFORMATION SERVICES

Edition 2.0
June 2023

urn:mrn:iala:pub:s1070:ed2.0
```

Strategy:

1. The `IALA <TYPE>` line is always at the top. Map label → doctype
   (`IALA STANDARD` → `standard`, `IALA RECOMMENDATION` → `recommendation`,
   etc.).
2. The code is a single line matching `\A[A-Z]\d{4}(-\d+)*\z`.
3. The title is everything between the code and the next blank line,
   joined with spaces.
4. `Edition X.Y` is matched literally.
5. The date line matches `\A<Month> \d{4}\z`.
6. The URN line matches `\Aurn:mrn:iala:pub:...\z`.

### Acceptance

- [ ] `spec/iala_fetcher/cover_page_parser_spec.rb` parses the
      `pdftotext` output of `s1070.pdf` (real first-page text fixture
      committed under `spec/fixtures/iala/cover_s1070.txt`) and asserts
      every field.
- [ ] `CoverPageOcr` reads API key from `~/.zai-api-key` (test with
      `ENV["Z_AI_API_KEY"]` set, no actual network call in specs).
- [ ] `PdfDownloader` caches by URL hash and doesn't re-download.
- [ ] No doubles.
