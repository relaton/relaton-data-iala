# 03 — IalaFetcher::Docid

**Priority:** P0 (gated by 02; depends on Pubid::Iala being available).

## Why

Every fetcher needs a single value object that holds an IALA document
identifier in all its forms: bare (`S1070`), with edition (`S1070 Ed 2.0`),
with language (`R1016:ed2.0(F)`), and URN
(`urn:mrn:iala:pub:s1070:ed2.0`). Wrapping `Pubid::Iala::Identifier`
gives us parsing + rendering + URN for free; this layer adds id/filename
derivation specific to relaton-data-iala.

## Scope

### `lib/iala_fetcher/docid.rb`

```ruby
class IalaFetcher::Docid
  def initialize(pubid:)              # wraps a Pubid::Iala::Identifier
  def self.from_code(str)             # "S1070", "R0126:ed2.0", "C0103-1"
  def self.from_cover(str)            # "IALA S1070 Ed 2.0 (F)" (cover-page form)
  def self.from_urn(urn)              # "urn:mrn:iala:pub:s1070:ed2.0"
  def self.from_listing_cell(str)     # "R1016:fr" (the listing-page :fr-suffixed form)

  def to_s                            # human form (delegates to Pubid::Iala renderer)
  def urn                             # MRN URN
  def id                              # relaton `id` field, e.g. "S1070-2.0"
  def filename_stem                   # lowercase id, e.g. "s1070_2.0"
  def with_language(lang_letter)      # returns a new Docid with language set
  def language                        # "E" / "F" / nil
  def work                            # returns a Docid with no language
  def ==(other)
end
```

### Filename convention (mirrors OIML)

| Item            | `id`                | Filename                       |
|-----------------|---------------------|--------------------------------|
| Work            | `S1070-2.0`         | `data/s1070_2.0.yaml`          |
| EN instance     | `S1070-2.0-E`       | `data/s1070_2.0_eng.yaml`      |
| FR instance     | `S1070-2.0-F`       | `data/s1070_2.0_fra.yaml`      |
| Sub-part work   | `C0103-1-3.0`       | `data/c0103-1_3.0.yaml`        |

The `_eng` / `_fra` suffix on instance filenames uses ISO 639-3 (relaton
convention); the docid suffix uses the single-letter OIML-style code.

### Language maps (in `lib/iala_fetcher.rb`)

```ruby
LANG_CODE = {
  "english"    => "eng", "french"    => "fra", "spanish"   => "spa",
  "chinese"    => "zho", "arabic"    => "ara", "russian"   => "rus",
}.freeze

DOCID_LANG_CODE = {
  "eng" => "E", "fra" => "F", "spa" => "S",
  "zho" => "C", "ara" => "A", "rus" => "R",
}.freeze
```

Use `.fetch(key)` (no default). A missing key means the map is incomplete.

### Acceptance

- [ ] `from_code("S1070").to_s == "IALA S1070"`
- [ ] `from_cover("IALA S1070 Ed 2.0").id == "S1070-2.0"`
- [ ] `from_cover("IALA S1070 Ed 2.0").filename_stem == "s1070_2.0"`
- [ ] `from_urn("urn:mrn:iala:pub:s1070:ed2.0").to_s == "IALA S1070 Ed 2.0"`
- [ ] `from_listing_cell("R1016:fr").language == "F"`
- [ ] `from_code("S1070").with_language("F").filename_stem == "s1070_2.0_fra"` (after edition is attached)
- [ ] `spec/iala_fetcher/docid_spec.rb` covers all four constructors and the derived forms.

### Out of scope

- PDF filename parsing (IALA's `?download=true` doesn't expose stable filenames).
