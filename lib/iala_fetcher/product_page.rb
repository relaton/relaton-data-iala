# frozen_string_literal: true

require "nokogiri"
require "uri"

module IalaFetcher
  # Scrapes a single IALA product detail page (the WordPress/WooCommerce
  # template at +/product/<slug>/+) into a +Detail+ value object.
  #
  # The page exposes a `<div itemscope>` block containing:
  #   - an h1 title
  #   - a `data` table with ID / Edition / Date / Revised Date / Committee
  #   - optional Format/Language attribute lines
  #   - an optional abstract inside `<div class="page">`
  #   - a download button linking to `?download=true` (the server streams
  #     the PDF directly with no redirect).
  class ProductPage
    Detail = Struct.new(
      :product_url, :post_id, :code, :title, :edition, :date, :revised_date,
      :committee, :format, :language, :abstract_html, :download_url,
      keyword_init: true,
    )

    attr_reader :url, :http_backend

    def initialize(url:, http_backend: IalaFetcher::Http.backend)
      @url = url
      @http_backend = http_backend
    end

    def fetch
      doc = Nokogiri::HTML(@http_backend.get(@url))
      parse_detail(doc)
    end

    private

    def parse_detail(doc)
      item_scope = doc.at_css("div.itemscope") || doc.at_css('div[class*="post-"]')
      raise ParseError, "No product itemscope found at #{@url}" unless item_scope

      post_id = item_scope[:class].to_s[/post-(\d+)/, 1]&.to_i
      title = item_scope.at_css("h1")&.text&.strip

      data = data_table(item_scope)
      code = data["ID"]
      edition = data["Edition"]
      date = data["Date"]
      revised_date = data["Revised Date"]
      committee = data["Committee"]

      format_lang = format_language(item_scope)
      download = download_url(item_scope)

      abstract = abstract_html(item_scope)

      Detail.new(
        product_url: @url,
        post_id: post_id,
        code: code,
        title: title,
        edition: edition,
        date: date,
        revised_date: revised_date,
        committee: committee,
        format: format_lang[:format],
        language: format_lang[:language],
        abstract_html: abstract,
        download_url: download,
      )
    end

    def data_table(item_scope)
      table = item_scope.at_css("table.product-details--data")
      return {} unless table

      table.css("tr").each_with_object({}) do |tr, acc|
        th = tr.at_css("th")&.text&.strip
        td = tr.at_css("td")&.text&.strip
        acc[th] = td if th && td && !td.empty?
      end
    end

    def format_language(item_scope)
      attr_block = item_scope.at_css(".product-details--attr")
      return { format: nil, language: nil } unless attr_block

      html = attr_block.inner_html
      {
        format: extract_strong_value(html, "Format"),
        language: extract_strong_value(html, "Language"),
      }
    end

    def extract_strong_value(html, label)
      m = html.match(/<strong>\s*#{label}:\s*<\/strong>\s*([^<]+)/i)
      m ? m[1].strip : nil
    end

    def download_url(item_scope)
      anchor = item_scope.at_css('a.btn[href*="download=true"]') ||
               item_scope.at_css('a.btn[href*="?download=true"]')
      return nil unless anchor && anchor["href"]

      URI.join(@url, anchor["href"]).to_s
    end

    def abstract_html(item_scope)
      node = item_scope.at_css('div.page[title^="Page"]')
      node ? node.inner_html.strip : nil
    end

    class ParseError < StandardError; end
  end
end
