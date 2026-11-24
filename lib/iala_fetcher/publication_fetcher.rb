# frozen_string_literal: true

require "date"
require "open3"

module IalaFetcher
  # Orchestrates the full scrape: CataloguePage → CrossLanguageLinker →
  # ProductPage → PdfDownloader → CoverPageParser, emitting one Work YAML
  # per code and one Instance YAML per language.
  #
  # Work YAMLs carry no `source` (the abstract Work has no PDF); each
  # Instance YAML carries the language-specific PDF and points back to
  # the Work via `relation: instanceOf`.
  class PublicationFetcher
    attr_reader :data_dir, :yaml_store, :http_backend,
                :categories, :pdf_downloader, :cover_page_ocr,
                :language_categories, :technical_catalogue

    # Product slugs and bare codes already covered — by the site walk
    # (#run) or by data/ (#run_reconciliation).
    Known = Struct.new(:slugs, :codes)

    PRODUCT_SLUG = %r{/product/([^/?#]+)/?\z}

    # @param technical_catalogue [IalaFetcher::TechnicalCatalogue, nil]
    #   when given, its product links fill gaps in the site walk, and its
    #   summaries fill English abstracts the product pages lack.
    def initialize(
      data_dir:,
      yaml_store:,
      http_backend: IalaFetcher::Http.backend,
      categories: IalaFetcher::TYPES.keys,
      pdf_downloader: nil,
      cover_page_ocr: nil,
      language_categories: IalaFetcher::LANGUAGE_CATEGORIES,
      technical_catalogue: nil
    )
      @data_dir = data_dir
      @yaml_store = yaml_store
      @http_backend = http_backend
      @categories = categories
      @pdf_downloader = pdf_downloader
      @cover_page_ocr = cover_page_ocr
      @language_categories = language_categories
      @technical_catalogue = technical_catalogue
    end

    def run
      FileUtils.mkdir_p(@data_dir)

      rows_by_category = collect_rows
      add_catalogue_rows!(rows_by_category, known_from_rows(rows_by_category)) if @technical_catalogue
      emit_all(rows_by_category)
    end

    # Emits only the catalogue products that data/ does not cover yet. No
    # site walk, and existing files stay as they are.
    def run_reconciliation
      raise ArgumentError, "technical_catalogue: is required for run_reconciliation" unless @technical_catalogue

      FileUtils.mkdir_p(@data_dir)
      rows_by_category = {}
      add_catalogue_rows!(rows_by_category, known_from_store)
      emit_all(rows_by_category)
    end

    private

    def emit_all(rows_by_category)
      linker = IalaFetcher::CrossLanguageLinker.new(
        rows_by_category, language_for_category: @language_categories,
      )

      groups = linker.groups
      warn "  Emitted #{groups.length} work groups across #{rows_by_category.values.flatten.length} rows"
      groups.each do |group|
        emit_group(group)
      rescue StandardError => e
        warn "  ERROR emitting #{group&.work_natural_key}: #{e.message}"
      end
    end

    # ---- Catalogue reconciliation ----

    # Known codes count only English rows: a code listed only in a
    # translation category still lacks its English Instance, which the
    # catalogue's (English) product page provides.
    def known_from_rows(rows_by_category)
      english = rows_by_category.select { |slug, _| @language_categories[slug] == "eng" }.values.flatten
      Known.new(
        rows_by_category.values.flatten.filter_map { |r| slug_of(r.product_url) }.to_set,
        english.reject(&:codeless?).map { |r| r.bare_code.upcase }.to_set,
      )
    end

    def known_from_store
      known = Known.new(Set.new, Set.new)
      @yaml_store.each_yaml do |name, _path|
        data = @yaml_store.read(name)
        slug = slug_of(data.dig("ext", "webpage"))
        known.slugs << slug if slug
        code, _edition = IalaFetcher::TechnicalCatalogue.primary_code(data)
        known.codes << code if code && Array(data["language"]).include?("eng")
      end
      known
    end

    def slug_of(url)
      url.to_s[PRODUCT_SLUG, 1]&.downcase
    end

    # Category for a `g1164`-style slug, or nil for other slugs (legacy
    # long names), whose code is known only after the page fetch.
    def category_from_slug(slug)
      letter = slug[/\A([srgcm])\d{4}/, 1]
      letter && IalaFetcher::CATALOGUE_PREFIX_CATEGORY.fetch(letter.upcase)
    end

    # Fetches each catalogue product page whose slug the walk did not see,
    # and adds a Row for it unless its code is already known. Rows go under
    # the English category for the code letter, so the linker and the emit
    # path treat them like any listing row.
    def add_catalogue_rows!(rows_by_category, known)
      @technical_catalogue.product_urls.each do |url|
        slug = slug_of(url)
        next if known.slugs.include?(slug)

        known.slugs << slug
        guessed = category_from_slug(slug)
        next if guessed && !matches_requested?(guessed)

        add_catalogue_row!(rows_by_category, known, url)
      end
    end

    # Network and page-shape failures skip one product. A missing
    # CATALOGUE_PREFIX_CATEGORY key raises (strict map).
    def add_catalogue_row!(rows_by_category, known, url)
      row = catalogue_row(url)
      return unless row && !known.codes.include?(row.bare_code.upcase)
      return unless matches_requested?(row.category_slug)

      known.codes << row.bare_code.upcase
      warn "  Catalogue adds #{row.code} (#{url})"
      (rows_by_category[row.category_slug] ||= []) << row
    rescue IalaFetcher::Http::Error, IalaFetcher::ProductPage::ParseError, Date::Error => e
      warn "  Catalogue product #{url}: #{e.message}"
    end

    def catalogue_row(url)
      detail = IalaFetcher::ProductPage.new(url: url, http_backend: @http_backend).fetch
      code = detail.code.to_s.strip
      return nil if code.empty?

      IalaFetcher::CataloguePage::Row.new(
        post_id: detail.post_id,
        code: code,
        title: detail.title,
        date: detail.date && Date.parse(detail.date),
        language_cell: detail.language && "#{detail.format}: #{detail.language}",
        product_url: url,
        category_slug: IalaFetcher::CATALOGUE_PREFIX_CATEGORY.fetch(code[0].upcase),
      )
    end

    # The catalogue summary as a plain-text English abstract, or nil when
    # the catalogue has no entry for this code at this edition.
    def catalogue_abstract(code, edition)
      summary = @technical_catalogue&.summary_for(code, edition: edition)
      return nil unless summary

      { "content" => summary, "language" => "eng", "format" => "text/plain" }
    end

    def collect_rows
      hash = {}
      @language_categories.keys.each do |slug|
        next unless matches_requested?(slug)

        hash[slug] = IalaFetcher::CataloguePage.new(
          slug: slug, http_backend: @http_backend,
        ).each_row.to_a
      rescue IalaFetcher::Http::BadStatus => e
        warn "  Skipping category #{slug}: #{e.message}"
        hash[slug] = []
      end
      hash
    end

    # A category is requested if it's in the requested set, or it's a
    # language variant of a requested category. E.g. if the user asked
    # for `recommendations`, the French/Spanish/Arabic/Chinese/Russian
    # recommendation categories are included.
    def matches_requested?(slug)
      return true if @categories.include?(slug)

      base = slug.sub(/-(french|spanish|arabic|chinese|russian)\z/, "")
      @categories.include?(base)
    end

    def emit_group(group)
      work_docid = work_docid_for(group)
      work_hash, work_docid = build_work_hash(group, work_docid)
      yaml_store.write(work_docid.filename_stem, work_hash)

      group.instances_by_language.each do |lang, row|
        emit_instance(group, row, lang, work_docid)
      rescue StandardError => e
        warn "  ERROR emitting instance #{work_docid}:#{lang}: #{e.message}"
      end
    end

    # Build the Work's Docid from the group's natural key + doctype.
    # Typed codes (S/R/G/M/C) go through from_code; resolution numbers
    # and slug-derived ids go through from_natural_key.
    def work_docid_for(group)
      IalaFetcher::Docid.from_natural_key(
        group.work_natural_key, doctype: group.work_doctype,
      ).work
    end

    # Returns [hash, work_docid_with_edition] so the caller can derive
    # the matching filename and pass the updated docid to emit_instance.
    def build_work_hash(group, work_docid)
      english_detail = product_detail_for(group.instances_by_language["eng"])
      work_docid = work_docid_with_edition(work_docid, english_detail, nil)
      cover = cover_for(english_detail, name: work_docid.filename_stem)
      work_docid = work_docid_with_edition(work_docid, english_detail, cover)

      titles = titles_for(group, cover)
      abstracts = abstracts_for(group)
      if abstracts.empty? && group.instances_by_language.key?("eng")
        abstracts = [catalogue_abstract(group.work_natural_key, work_docid.edition)].compact
      end
      date = published_date(english_detail, cover)
      committee = english_detail&.committee

      hash = {
        "id" => work_docid.id,
        "type" => "standard",
        "title" => titles,
        "docidentifier" => [{
          "content" => work_docid.to_s,
          "type" => "IALA",
          "primary" => true,
        }],
        "docnumber" => docnumber_for(work_docid),
        "contributor" => contributors(committee, group.work_doctype),
        "language" => titles.map { |t| t["language"] }.uniq,
        "script" => scripts_for(group),
        "status" => { "stage" => { "content" => "in-force" } },
        "ext" => ext_block(work_docid, group.work_doctype, committee,
                           english_detail&.product_url,
                           work_urn_for(work_docid, cover)),
      }
      hash["abstract"] = abstracts unless abstracts.empty?
      apply_dates!(hash, date)
      apply_copyright!(hash, date)
      add_instance_relations!(hash, group, work_docid)
      [hash, work_docid]
    end

    def emit_instance(group, row, lang, work_docid)
      detail = product_detail_for(row)
      lang_letter = IalaFetcher::DOCID_LANG_CODE.fetch(lang.to_s)

      instance_docid =
        work_docid_with_edition(work_docid, detail, nil)
        .with_language(lang_letter)

      cover = cover_for(detail, name: instance_docid.filename_stem)
      instance_docid =
        work_docid_with_edition(work_docid, detail, cover)
        .with_language(lang_letter)

      title = instance_title(detail, cover, lang)
      abstract = instance_abstract(detail, lang)
      abstract ||= catalogue_abstract(group.work_natural_key, instance_docid.edition) if lang.to_s == "eng"
      date = published_date(detail, cover)

      hash = {
        "id" => instance_docid.id,
        "type" => "standard",
        "title" => [title].compact,
        "source" => [IalaFetcher::Source.url(detail&.download_url || row.product_url)],
        "docidentifier" => [{
          "content" => instance_docid.to_s,
          "type" => "IALA",
          "primary" => true,
        }],
        "docnumber" => docnumber_for(instance_docid),
        "contributor" => contributors(detail&.committee, group.work_doctype),
        "language" => [lang.to_s],
        "script" => [script_for_language(lang.to_s)],
        "status" => { "stage" => { "content" => "in-force" } },
        "relation" => [{
          "type" => "instanceOf",
          "bibitem" => {
            "docidentifier" => [{ "content" => work_docid.to_s, "type" => "IALA" }],
          },
        }],
        "ext" => ext_block(
          instance_docid, group.work_doctype, detail&.committee,
          row.product_url, cover&.urn || instance_docid.urn,
        ),
      }
      hash["abstract"] = [abstract] if abstract
      apply_dates!(hash, date)
      apply_copyright!(hash, date)
      yaml_store.write(instance_docid.filename_stem, hash)
    end

    # ---- Helpers ----

    def product_detail_for(row)
      return nil unless row&.product_url

      IalaFetcher::ProductPage.new(
        url: row.product_url, http_backend: @http_backend,
      ).fetch
    rescue StandardError => e
      warn "    product page #{row&.product_url}: #{e.message}"
      nil
    end

    def cover_for(detail, name:)
      return nil unless detail&.download_url && @pdf_downloader

      pdf_path = @pdf_downloader.fetch(detail.download_url, name: name)
      text = extract_first_page_text(pdf_path)
      text = ocr_first_page(pdf_path, name: name) if (text.nil? || text.strip.empty?) && @cover_page_ocr
      return nil unless text && !text.strip.empty?

      IalaFetcher::CoverPageParser.parse(text)
    rescue StandardError => e
      warn "    cover page parse: #{e.message}"
      nil
    end

    def extract_first_page_text(pdf_path)
      out, status = Open3.capture2("pdftotext", "-layout", "-l", "1", pdf_path, "-")
      return nil unless status.success? && !out.empty?

      out
    rescue StandardError
      nil
    end

    def ocr_first_page(pdf_path)
      return nil unless @cover_page_ocr

      @cover_page_ocr.ocr_first_page(pdf_path)
    end

    def work_docid_with_edition(work_docid, detail, cover)
      edition = (detail && detail.edition && !detail.edition.empty? && detail.edition) ||
                (cover && cover.edition)
      return work_docid unless edition

      work_docid.with_edition(edition)
    end

    # The Work's URN. Prefers the cover-page URN (authoritative source —
    # printed on the cover by IALA). Falls back to computing one from the
    # Work docid for typed codes. Returns nil for codeless items.
    def work_urn_for(work_docid, cover)
      return cover.urn if cover&.urn && !cover.urn.empty?

      work_docid.urn
    end

    # Work-level abstracts: one per language that has one on the product
    # page. Standards (S1010, S1020, S1070) carry website-side abstracts
    # in `<div class="page">`; most other categories do not.
    def abstracts_for(group)
      group.instances_by_language.each_with_object([]) do |(lang, row), acc|
        detail = product_detail_for(row)
        html = detail&.abstract_html
        next unless html && !html.strip.empty?

        acc << {
          "content" => clean_abstract_html(html),
          "language" => lang.to_s,
          "format" => "text/html",
        }
      end
    end

    def instance_abstract(detail, lang)
      html = detail&.abstract_html
      return nil unless html && !html.strip.empty?

      {
        "content" => clean_abstract_html(html),
        "language" => lang.to_s,
        "format" => "text/html",
      }
    end

    # Nokogiri's inner_html on a fragment can leave leading/trailing
    # whitespace and entity-encoded characters. Strip and normalise.
    def clean_abstract_html(html)
      html.strip
    end

    def titles_for(group, cover)
      titles = []
      group.instances_by_language.each do |lang, row|
        detail = product_detail_for(row)
        content = instance_title_content(detail, cover, lang) || row.title
        next unless content

        titles << {
          "language" => lang.to_s,
          "content" => content,
          "type" => "main",
        }
      end
      titles
    end

    def instance_title(detail, cover, lang)
      content = instance_title_content(detail, cover, lang)
      return nil unless content

      {
        "language" => lang.to_s,
        "content" => content,
        "type" => "main",
      }
    end

    def instance_title_content(detail, cover, _lang)
      cover&.title || detail&.title
    end

    def published_date(detail, cover)
      from_text = detail&.date || cover&.month_year
      return nil unless from_text && !from_text.empty?

      Date.parse(from_text)
    rescue ArgumentError
      nil
    end

    def contributors(committee_code, _doctype)
      list = [IalaFetcher.iala_publisher_contributor]
      if committee_code && !committee_code.empty?
        committee_name = IalaFetcher::COMMITTEES.fetch(committee_code.to_s) do |code|
          warn "    Unknown committee: #{code}"
          code
        end
        list << {
          "role" => [{ "type" => "author", "description" => [{ "content" => "committee" }] }],
          "organization" => {
            "name" => [{ "content" => IalaFetcher::IALA_NAME }],
            "subdivision" => [{ "name" => [{ "content" => committee_name }] }],
            "abbreviation" => { "content" => IalaFetcher::IALA_ABBR },
          },
        }
      end
      list
    end

    # `docnumber` is a free-form string for relaton. For typed codes we
    # emit the bare number ("1070"); for resolution/slug ids we emit the
    # whole natural key (no clean number to extract).
    def docnumber_for(docid)
      return docid.code unless docid.typed

      docid.code[/\d+(?:-\d+)*/]
    end

    def scripts_for(group)
      group.instances_by_language.keys.map { |lang| script_for_language(lang.to_s) }.uniq
    end

    def script_for_language(lang)
      case lang
      when "eng", "fra", "spa" then "Latn"
      when "rus" then "Cyrl"
      when "ara" then "Arab"
      when "zho" then "Hans"
      else "Latn"
      end
    end

    def ext_block(docid, doctype, committee, webpage, urn)
      ext = {
        "doctype" => { "content" => doctype },
        "flavor" => "iala",
      }
      ext["urn"] = urn if urn && !urn.empty?
      ext["committee"] = committee if committee && !committee.empty?
      ext["webpage"] = webpage if webpage
      ext
    end

    def apply_dates!(hash, date)
      return unless date

      hash["date"] = [{ "type" => "published", "from" => date.iso8601 }]
      hash["version"] = [{ "content" => date.iso8601 }]
    end

    def apply_copyright!(hash, date)
      return unless date

      hash["copyright"] = [{
        "from" => date.year.to_s,
        "owner" => [{ "organization" => IalaFetcher.iala_org_hash }],
      }]
    end

    def add_instance_relations!(hash, group, work_docid)
      hash["relation"] = group.instances_by_language.map do |lang, _row|
        lang_letter = IalaFetcher::DOCID_LANG_CODE.fetch(lang.to_s)
        {
          "type" => "hasInstance",
          "bibitem" => {
            "docidentifier" => [{
              "content" => work_docid.with_language(lang_letter).to_s,
              "type" => "IALA",
            }],
          },
        }
      end
    end
  end
end
