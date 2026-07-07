# 08 — IalaFetcher::PublicationFetcher (work + instance model)

**Priority:** P1 (gated by 03, 04, 05, 06, 07).

## Why

This is the orchestrator. It walks every category, scrapes every listing
page, scrapes every product page, downloads every PDF, OCRs every cover,
links languages, and emits the final `data/*.yaml` files.

## Scope

### `lib/iala_fetcher/publication_fetcher.rb`

```ruby
class IalaFetcher::PublicationFetcher
  def initialize(
    data_dir:,
    yaml_store:,
    http_backend: IalaFetcher::Http.backend,
    categories: IalaFetcher::TYPES.keys,
    languages: %i[en fr es],
    pdf_downloader:,
    cover_page_ocr:
  )
  def run
end
```

### Algorithm

```
for each category in categories:
  rows = CataloguePage.new(slug: category).each_row.to_a

build linker = CrossLanguageLinker.new(category => rows, …)

for each Group from linker.groups:
  work_docid = Docid.from_code(group.work_code)
  work_hash = build_work_hash(group, work_docid)
  yaml_store.write(work_docid.filename_stem, work_hash)

  for each (lang, row) in group.instances_by_language:
    detail = ProductPage.new(url: row.product_url).fetch
    cover  = fetch_cover(detail, pdf_downloader, cover_page_ocr)
    instance_docid = work_docid.with_language(IalaFetcher::DOCID_LANG_CODE[lang])
    instance_hash = build_instance_hash(detail, cover, lang, instance_docid, work_docid)
    yaml_store.write(instance_docid.filename_stem, instance_hash)
```

### `build_work_hash`

```ruby
{
  "id" => work_docid.id,
  "type" => "standard",
  "title" => [ { language: eng, content: title, type: main }, … ],
  "docidentifier" => [{
    "content" => work_docid.to_s,           # "IALA S1070 Ed 2.0"
    "type" => "IALA",
    "primary" => true,
  }],
  "docnumber" => work_docid.number,         # "1070"
  "date" => [{ type: "published", from: iso_date }],
  "contributor" => [ publisher, committee ],
  "language" => [ list of all instance languages ],
  "script" => [ "Latn" ],                   # or ["Latn", "Cyrl"] for Russian etc.
  "status" => { stage: { content: "in-force" } },
  "copyright" => [{ from: year, owner: [org_hash] }],
  "relation" => [{ type: "hasInstance", bibitem: { docidentifier: […] } }, …],
  "ext" => {
    "doctype" => { content: doctype },
    "flavor" => "iala",
    "committee" => committee_code,           # ARM, ENG, DTEC, VTS
    "urn" => work_docid.urn,
  },
}
```

### `build_instance_hash`

Same shape as work, plus:

- `source: [ IalaFetcher::Source.url(detail.download_url) ]`
- `language: [ lang ]` (single language)
- `relation: [{ type: "instanceOf", bibitem: { docidentifier: [work] } }]`
- `title: [{ language: lang, content: cover.title || detail.title }]`
- `ext.webpage` = `detail.product_url` (the human-facing landing page)
- `ext.urn` includes the language segment when present

### Committee mapping

IALA's four technical committees:

| Abbreviation | Name                                          |
|--------------|-----------------------------------------------|
| ARM          | AtoN Requirements and Management Committee    |
| ENG          | Engineering and Sustainability Committee      |
| DTEC         | Digital Technologies Committee                |
| VTS          | Vessel Traffic Services Committee             |

Plus `Council` / `Secretariat` for resolutions. Map abbreviations to
full names in a constant; emit as a `contributor` with
`role: [{ type: "author", description: "committee" }]` and
`organization.subdivision`.

### Acceptance

- [ ] `bundle exec iala-fetch --type=standards` produces 7 Work YAMLs +
      English instance YAMLs for each (since only English exists for
      standards today).
- [ ] `bundle exec iala-fetch --type=recommendations` produces Work YAMLs
      plus `eng`/`fra`/`spa` instance YAMLs as available.
- [ ] Every YAML round-trips through `Relaton::Bib::Item.from_yaml` →
      `to_yaml` byte-identically (verified by `check_data.rb`).
- [ ] Work YAML contains `relation: hasInstance` for every instance;
      every instance YAML contains `relation: instanceOf` back to the work.
- [ ] `ext.urn` populated on every record where the cover page provided
      one.
- [ ] No doubles in specs — use `Http::Fake` with real archived HTML
      fixtures.
