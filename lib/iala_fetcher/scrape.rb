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
    method_option :data_dir, type: :string, default: "data"
    method_option :pdfs_dir, type: :string, default: "pdfs"
    def fetch
      types = options[:type] || []
      languages = (options[:language]&.map(&:to_sym)) || []
      store = IalaFetcher::YamlStore.new(options[:data_dir])

      pdf_downloader = options[:pdfs] ? IalaFetcher::PdfDownloader.new(cache_dir: options[:pdfs_dir]) : nil
      cover_ocr = options[:pdfs] ? IalaFetcher::CoverPageOcr.new : nil

      categories = types.empty? ? IalaFetcher::TYPES.keys : types
      unless languages.empty?
        say "Note: language filter affects which translation categories are scraped, not Work/Instance selection.", :yellow
      end

      say "Fetching IALA publications (types=#{categories.inspect}, languages=#{languages.inspect}, pdfs=#{options[:pdfs]})", :cyan
      IalaFetcher::PublicationFetcher.new(
        data_dir: options[:data_dir],
        yaml_store: store,
        categories: categories,
        pdf_downloader: pdf_downloader,
        cover_page_ocr: cover_ocr,
      ).run

      say "Rebuilding indexes...", :cyan
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    desc "index", "Rebuild index-v1.yaml + index-v2.yaml from data/*.yaml"
    def index
      load File.expand_path("crawler.rb", Dir.pwd)
    end
  end
end
