# frozen_string_literal: true

require "thor"

module IalaFetcher
  class Scrape < Thor
    def self.exit_on_failure? = true

    default_task :fetch

    desc "fetch", "Fetch IALA publications from iala.int into data/"
    method_option :type, type: :string, repeatable: true,
                         desc: "Category slug to fetch (e.g. standards, recommendations). Defaults to all."
    method_option :language, type: :string, repeatable: true,
                             desc: "ISO 639-3 language code to fetch (e.g. en, fr, es). Defaults to all available."
    method_option :pdfs, type: :boolean, default: false,
                         desc: "Download PDFs and OCR cover pages for fields not on the website."
    method_option :catalogue, type: :boolean, default: true,
                              desc: "Use the Technical Documents Catalogue to add products the listings miss " \
                                    "and to fill English abstracts."
    method_option :catalogue_url, type: :string,
                                  desc: "Catalogue PDF URL. Defaults to the newest edition linked from iala.int."
    method_option :data_dir, type: :string, default: "data"
    method_option :pdfs_dir, type: :string, default: "pdfs"
    def fetch
      types = options[:type] || []
      languages = (options[:language]&.map(&:to_sym)) || []
      store = IalaFetcher::YamlStore.new(options[:data_dir])

      pdf_downloader = options[:pdfs] ? IalaFetcher::PdfDownloader.new(cache_dir: options[:pdfs_dir]) : nil
      cover_ocr = options[:pdfs] ? IalaFetcher::CoverPageOcr.new : nil
      catalogue = options[:catalogue] ? technical_catalogue : nil

      categories = types.empty? ? IalaFetcher::TYPES.keys : types
      unless languages.empty?
        say "Note: language filter affects which translation categories are scraped, not Work/Instance selection.", :yellow
      end

      say "Fetching IALA publications (types=#{categories.inspect}, languages=#{languages.inspect}, " \
          "pdfs=#{options[:pdfs]}, catalogue=#{options[:catalogue]})", :cyan
      IalaFetcher::PublicationFetcher.new(
        data_dir: options[:data_dir],
        yaml_store: store,
        categories: categories,
        pdf_downloader: pdf_downloader,
        cover_page_ocr: cover_ocr,
        technical_catalogue: catalogue,
      ).run

      say "Rebuilding indexes...", :cyan
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    desc "catalogue", "Add catalogue products missing from data/ and backfill English abstracts (no site walk)"
    method_option :catalogue_url, type: :string,
                                  desc: "Catalogue PDF URL. Defaults to the newest edition linked from iala.int."
    method_option :data_dir, type: :string, default: "data"
    method_option :pdfs_dir, type: :string, default: "pdfs"
    def catalogue
      store = IalaFetcher::YamlStore.new(options[:data_dir])
      catalogue = technical_catalogue

      say "Reconciling data/ against the catalogue...", :cyan
      IalaFetcher::PublicationFetcher.new(
        data_dir: options[:data_dir], yaml_store: store, technical_catalogue: catalogue,
      ).run_reconciliation

      changed = IalaFetcher::AbstractBackfill.new(yaml_store: store, technical_catalogue: catalogue).run
      say "Backfilled abstracts in #{changed} files.", :cyan

      say "Rebuilding indexes...", :cyan
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    desc "index", "Rebuild index-v1.yaml + index-v2.yaml from data/*.yaml"
    def index
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    no_commands do
      # Downloads (or reuses the cached copy of) the catalogue PDF. The
      # cache name is the URL's last path segment, so a new edition is a
      # new file.
      def technical_catalogue
        url = options[:catalogue_url] || IalaFetcher::TechnicalCatalogue.latest_url
        say "Catalogue: #{url}", :cyan
        name = File.basename(url.sub(/[?#].*\z/, ""), ".pdf")
        path = IalaFetcher::PdfDownloader.new(cache_dir: options[:pdfs_dir]).fetch(url, name: name)
        IalaFetcher::TechnicalCatalogue.new(path)
      end
    end
  end
end
