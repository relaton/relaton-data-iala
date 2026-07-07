# frozen_string_literal: true

require "digest"
require "fileutils"

module IalaFetcher
  # Downloads PDFs (the IALA `<product-url>?download=true` endpoint
  # streams `application/pdf` directly — no redirect). Caches by URL hash
  # so re-runs are free.
  class PdfDownloader
    attr_reader :cache_dir, :http_backend

    def initialize(cache_dir: "pdfs", http_backend: IalaFetcher::Http.backend)
      @cache_dir = File.expand_path(cache_dir)
      @http_backend = http_backend
      FileUtils.mkdir_p(@cache_dir)
    end

    def fetch(url)
      path = path_for(url)
      return path if File.exist?(path)

      FileUtils.mkdir_p(File.dirname(path))
      body = http_backend.get(url)
      File.binwrite(path, body)
      path
    end

    def cached?(url)
      File.exist?(path_for(url))
    end

    def path_for(url)
      hash = Digest::SHA1.hexdigest(url)
      File.join(@cache_dir, "#{hash}.pdf")
    end
  end
end
