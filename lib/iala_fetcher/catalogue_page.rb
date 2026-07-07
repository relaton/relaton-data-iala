# frozen_string_literal: true

require "nokogiri"
require "date"
require "uri"

module IalaFetcher
  # Walks a paginated WooCommerce product-category listing and yields one
  # +Row+ per product. The listing page is server-rendered HTML; the
  # caller decides which slug to pass (English canonical, French, etc.).
  #
  # Each row in the table looks like:
  #
  #   <tr class="post-NNNNN product type-product …product_cat-<slug>…">
  #     <td class="highlight"><strong>S1020</strong></td>
  #     <td><a href="https://www.iala.int/product/s1020/" class="woocommerce-LoopProduct-link">S1020 Title</a></td>
  #     <td>03 June 2023</td>
  #     <td>PDF: English</td>           <!-- optional -->
  #   </tr>
  class CataloguePage
    Row = Struct.new(
      :post_id, :code, :title, :date, :language_cell, :product_url,
      :category_slug, keyword_init: true,
    ) do
      def language_marker
        return nil unless language_cell && !language_cell.empty?

        language_cell[/\b(English|French|Spanish|Arabic|Chinese|Russian)\b/, 1]
      end
    end

    BASE_PATH = "/product-category/publications".freeze

    attr_reader :slug, :http_backend

    def initialize(slug:, http_backend: IalaFetcher::Http.backend)
      @slug = slug.to_s
      @http_backend = http_backend
    end

    def each_row
      return enum_for(:each_row) unless block_given?

      each_page do |page_number, doc|
        rows_from(doc).each { |row| yield row }
      end
    end

    def each_page
      return enum_for(:each_page) unless block_given?

      max_page = 1
      current = 1
      visited = []

      while current <= max_page && !visited.include?(current)
        visited << current
        url = url_for_page(current)
        doc = Nokogiri::HTML(@http_backend.get(url))
        yield current, doc

        discovered = max_page_number(doc)
        max_page = discovered if discovered && discovered > max_page
        current += 1
      end
    end

    def url_for_page(n)
      n <= 1 ? "#{IalaFetcher::BASE_URL}#{BASE_PATH}/#{@slug}/" : "#{IalaFetcher::BASE_URL}#{BASE_PATH}/#{@slug}/page/#{n}/"
    end

    private

    def rows_from(doc)
      doc.css("tr.product.type-product").map { |tr| row_from(tr) }.compact
    end

    def row_from(tr)
      class_attr = tr["class"].to_s
      post_id = class_attr[/post-(\d+)/, 1]&.to_i
      return nil unless post_id

      highlight = tr.at_css("td.highlight strong")
      code_text = highlight ? highlight.text.strip : nil
      return nil unless code_text

      link = tr.at_css("a.woocommerce-LoopProduct-link")
      product_url = link && link["href"]
      title = link ? link.text.strip : nil

      tds = tr.css("td").to_a
      date_td = tds[2]
      date_text = date_td ? date_td.text.strip : nil

      language_cell = (tds[3] && tds[3].text.strip.to_s) || nil
      language_cell = nil if language_cell && language_cell.empty?

      Row.new(
        post_id: post_id,
        code: code_text,
        title: title,
        date: parse_date(date_text),
        language_cell: language_cell,
        product_url: product_url,
        category_slug: @slug,
      )
    end

    def parse_date(text)
      return nil unless text && !text.empty?

      Date.parse(text)
    rescue ArgumentError
      # IALA dates are always "DD Month YYYY"; anything else is unexpected.
      nil
    end

    # WooCommerce pagination exposes anchor links of the form
    # `<base>/<slug>/page/N/`. Returns the highest N discovered, or 1 if
    # the page lists no pagination widget (small categories).
    def max_page_number(doc)
      numbers = doc.css('a[href*="/page/"]').map do |a|
        a["href"][%r{/page/(\d+)/?\z}, 1]&.to_i
      end.compact
      numbers.empty? ? 1 : numbers.max
    end
  end
end
