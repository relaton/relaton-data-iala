# frozen_string_literal: true

require "net/http"
require "json"
require "digest"
require "fileutils"
require "base64"

module IalaFetcher
  # GLM-OCR wrapper for IALA PDFs whose first page has no extractable
  # text layer. Mirrors the backfill/glm_ocr.rb approach from
  # relaton-data-oiml, but as a maintained library component.
  #
  # The fetcher prefers `pdftotext`; this is the fallback. Reads the API
  # key from `~/.zai-api-key` or `ENV["Z_AI_API_KEY"]`. Never hardcodes
  # the key, never commits it.
  class CoverPageOcr
    ENDPOINT = URI("https://api.z.ai/api/paas/v4/layout_parsing").freeze
    PAGES_PER_CHUNK = 30

    attr_reader :api_key, :cache_dir

    def initialize(api_key: self.class.read_api_key, cache_dir: "pdfs/ocr-cache")
      @api_key = api_key
      @cache_dir = File.expand_path(cache_dir)
      FileUtils.mkdir_p(@cache_dir)
    end

    def self.read_api_key
      env = ENV["Z_AI_API_KEY"]
      return env if env && !env.include?("=") && !env.start_with?("export ")

      path = File.expand_path("~/.zai-api-key")
      return nil unless File.exist?(path)

      raw = File.read(path).strip
      m = raw.match(/\A(?:export\s+)?(?:Z_AI_API_KEY|ZAI_API_KEY)\s*=\s*["']?([^"'\s]+)["']?\z/)
      m ? m[1] : raw
    end

    # OCRs only the first page of the PDF. Returns markdown text.
    # `name` is the caller-chosen cache key — typically the instance
    # docid's filename stem (e.g. "s1070-2.0-e") so the cache entry is
    # human-browsable: pdfs/ocr-cache/s1070-2.0-e.md.
    def ocr_first_page(file_input, name:)
      chunk(file_input, 1, 1, name: name)
    end

    # OCRs an arbitrary page window (1-indexed, inclusive). Cached per
    # (name, window) so re-runs are free. Falls back to a SHA256 of the
    # file_input when `name` is nil (back-compat).
    def chunk(file_input, start_page, end_page, name: nil)
      key = cache_key_for(file_input, start_page, end_page, name: name)
      cached = read_cache(key)
      return cached if cached

      res = request(file_input, start_page, end_page)
      md = res["md_results"] || ""
      write_cache(key, md)
      md
    end

    private

    def request(file_input, start_page, end_page)
      raise "GLM API key missing — set Z_AI_API_KEY or ~/.zai-api-key" unless @api_key

      body = {
        "model" => "glm-ocr",
        "file" => as_file_field(file_input),
        "start_page_id" => start_page,
        "end_page_id" => end_page,
      }
      attempt_with_retry(body)
    end

    def attempt_with_retry(body, attempts: 5)
      delay = 30
      attempts.times do |n|
        http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
        http.use_ssl = ENDPOINT.scheme == "https"
        http.read_timeout = 600
        http.write_timeout = 120
        req = Net::HTTP::Post.new(ENDPOINT.request_uri,
                                  "Authorization" => "Bearer #{@api_key}",
                                  "Content-Type" => "application/json")
        req.body = JSON.generate(body)
        res = http.request(req)
        if res.is_a?(Net::HTTPSuccess)
          j = JSON.parse(res.body)
          raise "GLM-OCR error: #{j.inspect}" if j["error"] || j["code"]

          return j
        end
        if res.code == "429" && n < attempts - 1
          warn "  GLM-OCR 429 rate limit; retry in #{delay}s (attempt #{n + 1}/#{attempts})"
          sleep delay
          delay = [delay * 1.5, 300].min
          next
        end
        raise "GLM-OCR HTTP #{res.code}: #{res.body[0, 300]}"
      end
    end

    def as_file_field(input)
      return input if input.start_with?("http")

      mime = case File.extname(input).downcase
             when ".pdf" then "application/pdf"
             when ".png" then "image/png"
             when ".jpg", ".jpeg" then "image/jpeg"
             else "application/pdf"
             end
      "data:#{mime};base64,#{Base64.strict_encode64(File.binread(input))}"
    end

    def cache_key_for(input, start_page, end_page, name: nil)
      return safe_name(name) if name

      Digest::SHA256.hexdigest("#{input}|#{start_page}|#{end_page}")[0, 16]
    end

    def safe_name(name)
      name.to_s.gsub(/[^\w.\-]/, "_")
    end

    def read_cache(key)
      path = File.join(@cache_dir, "#{key}.md")
      File.exist?(path) ? File.read(path) : nil
    end

    def write_cache(key, md)
      File.write(File.join(@cache_dir, "#{key}.md"), md)
    end
  end
end
