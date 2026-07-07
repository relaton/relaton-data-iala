# frozen_string_literal: true

require "relaton/bib"

# IalaFetcher scrapes iala.int publications and translation pages into
# Relaton YAML files under data/.
module IalaFetcher
  BASE_URL = "https://www.iala.int".freeze

  IALA_NAME = "International Organization for Marine Aids to Navigation".freeze
  IALA_ABBR = "IALA".freeze
  IALA_LEGAL_NAME = "International Association of Marine Aids to Navigation " \
                    "and Lighthouse Authorities".freeze

  # Category slug → [prefix, doctype, language-defaults, sub-categories]
  # `prefix` is nil for categories without a type-letter code (manuals,
  # reports, other-publications).
  TYPES = {
    "standards"                              => ["S", "standard",         nil],
    "recommendations"                        => ["R", "recommendation",   nil],
    "guidelines"                             => ["G", "guideline",        nil],
    "manuals"                                => [nil, "manual",           nil],
    "model-courses"                          => ["C", "model-course",     nil],
    "model-courses/level-1-aton-manager-courses" => ["C", "model-course", nil],
    "model-courses/level-2-technician-courses" => ["C", "model-course",   nil],
    "model-courses/vts-model-courses"        => ["C", "model-course",     nil],
    "reports-and-proceedings"                => [nil, "report",           nil],
    "other-publications"                     => [nil, "resolution",       nil],
  }.freeze

  # Language categories — slug → ISO 639-3 code. Each maps a parallel
  # translation of the publications tree. English is the default; the
  # English slug is the canonical source for Work-level metadata.
  # All ten base categories have an English entry; recommendations and
  # manuals also have translation slugs that exist on the site today.
  LANGUAGE_CATEGORIES = {
    # English — all categories
    "standards"                                  => "eng",
    "recommendations"                            => "eng",
    "guidelines"                                 => "eng",
    "manuals"                                    => "eng",
    "model-courses"                              => "eng",
    "model-courses/level-1-aton-manager-courses" => "eng",
    "model-courses/level-2-technician-courses"   => "eng",
    "model-courses/vts-model-courses"            => "eng",
    "reports-and-proceedings"                    => "eng",
    "other-publications"                         => "eng",
    # French / Spanish / Arabic / Chinese / Russian variants
    "recommendations-french"                     => "fra",
    "recommendations-spanish"                    => "spa",
    "recommendation-arabic"                      => "ara",
    "recommendation-chinese"                     => "zho",
    "recommendation-russian"                     => "rus",
  }.freeze

  # ISO 639-3 → IALA single-letter docid language code (printed on covers).
  DOCID_LANG_CODE = {
    "eng" => "E",
    "fra" => "F",
    "spa" => "S",
    "zho" => "C",
    "ara" => "A",
    "rus" => "R",
  }.freeze

  # Inverse of DOCID_LANG_CODE — used to decode cover-page language tags.
  LANG_FROM_DOCID_CODE = DOCID_LANG_CODE.invert.freeze

  # IALA's technical committees plus governance bodies. Historical
  # committee codes appear on older publications and are preserved here
  # so the contributor block can render the full name.
  COMMITTEES = {
    "ARM"       => "AtoN Requirements and Management Committee",
    "ENG"       => "Engineering and Sustainability Committee",
    "DTEC"      => "Digital Technologies Committee",
    "VTS"       => "Vessel Traffic Services Committee",
    # Historical / sub-committee codes seen on legacy publications
    "e-NAV"     => "e-Navigation Committee",
    "ENAV"      => "e-Navigation Committee",
    "AtoN"      => "AtoN Requirements and Management Committee",
    "IS"        => "Information Systems Committee",
    # Governance bodies
    "Council"   => "IALA Council",
    "Secretariat" => "IALA Secretariat",
    "General Assembly" => "IALA General Assembly",
  }.freeze

  # Cover-page label → doctype vocabulary. The cover-page OCR uses these
  # to set ext.doctype.content when the listing page didn't.
  COVER_LABEL_TO_DOCTYPE = {
    "STANDARD"       => "standard",
    "RECOMMENDATION" => "recommendation",
    "GUIDELINE"      => "guideline",
    "MANUAL"         => "manual",
    "MODEL COURSE"   => "model-course",
  }.freeze

  def self.iala_org_hash
    {
      "name" => [{ "content" => IALA_NAME }],
      "abbreviation" => { "content" => IALA_ABBR },
    }
  end

  def self.iala_publisher_contributor
    {
      "role" => [{ "type" => "publisher" }],
      "organization" => iala_org_hash,
    }
  end

  # autoload entries — defined here so `require "iala_fetcher"` makes every
  # submodule available lazily. No `require_relative` in lib/.
  autoload :Docid,                "iala_fetcher/docid"
  autoload :Source,               "iala_fetcher/source"
  autoload :Http,                 "iala_fetcher/http"
  autoload :YamlStore,            "iala_fetcher/yaml_store"
  autoload :CataloguePage,        "iala_fetcher/catalogue_page"
  autoload :ProductPage,          "iala_fetcher/product_page"
  autoload :CrossLanguageLinker,  "iala_fetcher/cross_language_linker"
  autoload :PdfDownloader,        "iala_fetcher/pdf_downloader"
  autoload :CoverPageOcr,         "iala_fetcher/cover_page_ocr"
  autoload :CoverPageParser,      "iala_fetcher/cover_page_parser"
  autoload :PublicationFetcher,   "iala_fetcher/publication_fetcher"
  autoload :Indexer,              "iala_fetcher/indexer"
  autoload :Scrape,               "iala_fetcher/scrape"
end
