# frozen_string_literal: true

module IalaFetcher
  # Adds the Technical Documents Catalogue summary as the English abstract
  # of existing data/ items that have none — without a re-scrape, so
  # fields that came from earlier `--pdfs` runs stay as they are.
  #
  # Touches only items whose `language` includes `eng`, that have no
  # `abstract`, and whose primary docid edition is the catalogue's edition
  # for that code. Idempotent.
  class AbstractBackfill
    def initialize(yaml_store:, technical_catalogue:)
      @yaml_store = yaml_store
      @technical_catalogue = technical_catalogue
    end

    # @return [Integer] the number of files changed
    def run
      changed = 0
      @yaml_store.each_yaml do |name, _path|
        data = @yaml_store.read(name)
        next if data["abstract"]
        next unless Array(data["language"]).include?("eng")

        code, edition = IalaFetcher::TechnicalCatalogue.primary_code(data)
        summary = code && @technical_catalogue.summary_for(code, edition: edition)
        next unless summary

        data["abstract"] = [{ "content" => summary, "language" => "eng", "format" => "text/plain" }]
        @yaml_store.write(name, data)
        changed += 1
      end
      changed
    end
  end
end
