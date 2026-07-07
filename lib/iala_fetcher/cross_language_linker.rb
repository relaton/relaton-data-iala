# frozen_string_literal: true

module IalaFetcher
  # Groups CataloguePage::Row records that represent the same Work across
  # language-specific category pages. Each IALA publication is published
  # once per language; the underlying WordPress `post_id` is the same
  # across translations, which makes it the stable join key.
  #
  # The linker takes a hash of { category_slug => [Row, …] } and yields
  # one Group per distinct post_id, holding one Row per available
  # language.
  class CrossLanguageLinker
    Group = Struct.new(:work_code, :instances_by_language, :post_id, keyword_init: true) do
      def languages
        instances_by_language.keys
      end
    end

    attr_reader :rows_by_category, :language_for_category

    # @param rows_by_category [Hash{String=>Array<CataloguePage::Row>}]
    # @param language_for_category [Hash{String=>String}] maps category
    #   slug to ISO 639-3 language code. Defaults to
    #   IalaFetcher::LANGUAGE_CATEGORIES.
    def initialize(rows_by_category, language_for_category: nil)
      @rows_by_category = rows_by_category
      @language_for_category = language_for_category || IalaFetcher::LANGUAGE_CATEGORIES
    end

    def groups
      bucket.values.sort_by(&:work_code)
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
          lang = language_for_category.fetch(slug)
          rows.each do |row|
            b[row.post_id][lang] = row
          end
        end

        b.each_with_object({}) do |(post_id, instances_by_lang), acc|
          code = authoritative_code(instances_by_lang)
          acc[post_id] = Group.new(
            work_code: code,
            instances_by_language: instances_by_lang,
            post_id: post_id,
          )
        end
      end
    end

    # Picks the canonical code for a Work. English always wins when
    # available; otherwise the first by language code sort order. This
    # guards against future translation categories exposing a slightly
    # different code than the English listing.
    def authoritative_code(instances_by_lang)
      return instances_by_lang["eng"].code if instances_by_lang["eng"]

      instances_by_lang.min_by { |lang, _row| lang }.last.code
    end
  end
end
