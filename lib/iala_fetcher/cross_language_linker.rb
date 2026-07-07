# frozen_string_literal: true

module IalaFetcher
  # Groups CataloguePage::Row records that represent the same Work.
  #
  # Two patterns exist on the IALA site:
  #
  #   * **Modern translations** — one WooCommerce product (post_id) is
  #     listed under multiple language categories. R1016 has a single
  #     post_id; the English, French, Spanish category pages each show
  #     the same product with a translated title.
  #
  #   * **Legacy translations** — each language is its own product with
  #     its own post_id. A12-01-E (English) and A12-01-F (French) are
  #     distinct products that the catalogue treats as the same Work.
  #
  # Both patterns are unified by grouping on the **bare code** (the code
  # with all language suffixes stripped). Codeless items (reports-and-
  # proceedings) fall back to post_id grouping since they have no code
  # to share.
  class CrossLanguageLinker
    Group = Struct.new(
      :work_natural_key, :work_doctype, :instances_by_language, :post_id,
      keyword_init: true,
    ) do
      def languages
        instances_by_language.keys
      end
    end

    attr_reader :rows_by_category, :language_for_category

    # @param rows_by_category [Hash{String=>Array<CataloguePage::Row>}]
    # @param language_for_category [Hash{String=>String}, nil] maps category
    #   slug to ISO 639-3 language code. Defaults to
    #   IalaFetcher::LANGUAGE_CATEGORIES.
    def initialize(rows_by_category, language_for_category: nil)
      @rows_by_category = rows_by_category
      @language_for_category = language_for_category || IalaFetcher::LANGUAGE_CATEGORIES
    end

    def groups
      bucket.values.sort_by(&:work_natural_key)
    end

    def each_group
      return enum_for(:each_group) unless block_given?

      groups.each { |g| yield g }
    end

    private

    def bucket
      @bucket ||= begin
        b = Hash.new { |h, k| h[k] = {} }
        rows_by_category.each do |slug, rows|
          rows.each do |row|
            key = group_key_for(row)
            lang = language_for_row(row, slug)
            b[key][lang] = row
          end
        end

        b.each_with_object({}) do |(key, instances_by_lang), acc|
          authoritative = authoritative_row(instances_by_lang)
          acc[key] = Group.new(
            work_natural_key: natural_key_for(authoritative),
            work_doctype: doctype_for(authoritative),
            instances_by_language: instances_by_lang,
            post_id: authoritative.post_id,
          )
        end
      end
    end

    # Group key: bare_code when the row has a code, otherwise a synthetic
    # "post:<id>" key so codeless items don't all collapse together.
    def group_key_for(row)
      return "post:#{row.post_id}" if row.codeless?

      row.bare_code
    end

    # Pick the row's language, preferring the code-embedded marker over
    # the category slug. The category slug is the default for typed codes
    # without explicit markers (e.g. R1016 on the English listing).
    def language_for_row(row, slug)
      letter = row.code_language_letter
      return letter_to_iso(letter) if letter

      @language_for_category[slug] || "eng"
    end

    def letter_to_iso(letter)
      IalaFetcher::LANG_FROM_DOCID_CODE.fetch(letter)
    end

    # Picks the canonical row for a Work. English always wins when
    # available; otherwise the first by language code sort order. This
    # guards against future translation categories exposing a slightly
    # different code than the English listing.
    def authoritative_row(instances_by_lang)
      return instances_by_lang["eng"] if instances_by_lang["eng"]

      instances_by_lang.min_by { |lang, _row| lang }.last
    end

    # The bare code without language suffix, or the URL slug for codeless
    # items (reports-and-proceedings). Stable across translations.
    def natural_key_for(row)
      return row.bare_code unless row.codeless?

      slug_from_url(row.product_url)
    end

    def slug_from_url(url)
      url.to_s.sub(%r{/\z}, "").sub(%r{.*/product/}, "")
    end

    def doctype_for(row)
      entry = IalaFetcher::TYPES[row.category_slug]
      entry ? entry[1] : "standard"
    end
  end
end
