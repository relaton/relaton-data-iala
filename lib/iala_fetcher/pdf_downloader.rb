# frozen_string_literal: true

require "fileutils"
require "json"

module IalaFetcher
  # Downloads PDFs (the IALA `<product-url>?download=true` endpoint
  # streams `application/pdf` directly — no redirect). Caches by
  # caller-supplied name (typically the instance docid's filename stem,
  # e.g. `s1070-2.0-e`) so the cache is human-browsable:
  #
  #   pdfs/s1070-2.0-e.pdf
  #   pdfs/r0126-2.0-fra.pdf
  #
  # A JSON sidecar (`pdfs/manifest.json`) maps `url ↔ name` so re-requests
  # short-circuit and the original URL is recoverable from the cache.
  class PdfDownloader
    MANIFEST_FILE = "manifest.json".freeze

    attr_reader :cache_dir, :http_backend

    def initialize(cache_dir: "pdfs", http_backend: IalaFetcher::Http.backend)
      @cache_dir = File.expand_path(cache_dir)
      @http_backend = http_backend
      FileUtils.mkdir_p(@cache_dir)
    end

    # @param url [String] the download URL
    # @param name [String] filename stem for the cache (e.g. "s1070-2.0-e")
    # @return [String] the local path of the cached PDF
    def fetch(url, name:)
      path = path_for(name)
      return path if File.exist?(path)

      FileUtils.mkdir_p(File.dirname(path))
      body = http_backend.get(url)
      File.binwrite(path, body)
      record_in_manifest(url, name)
      path
    end

    def cached?(name)
      File.exist?(path_for(name))
    end

    def path_for(name)
      File.join(@cache_dir, "#{safe_name(name)}.pdf")
    end

    # The URL associated with a cached name, if known. `nil` for entries
    # that predate the manifest or weren't fetched through this downloader.
    def url_for(name)
      manifest["name_to_url"][safe_name(name)]
    end

    private

    # Restrict to filesystem/wire-safe characters. Slashes become `_` so
    # subdirectory-style codes (e.g. `model-courses/level-1`) don't escape
    # the cache_dir.
    def safe_name(name)
      name.to_s.gsub(/[^\w.\-]/, "_")
    end

    def manifest
      @manifest ||= begin
        path = File.join(@cache_dir, MANIFEST_FILE)
        if File.exist?(path)
          JSON.parse(File.read(path))
        else
          { "name_to_url" => {}, "url_to_name" => {} }
        end
      end
    end

    def record_in_manifest(url, name)
      sname = safe_name(name)
      manifest["name_to_url"][sname] = url
      manifest["url_to_name"][url] = sname
      File.write(File.join(@cache_dir, MANIFEST_FILE), JSON.pretty_generate(manifest))
    end
  end
end
