# frozen_string_literal: true

require "pdf-reader"
require "uri"

module IalaFetcher
  # Reads the IALA Technical Documents Catalogue PDF — IALA's own complete
  # inventory of technical documents, re-issued per edition (Ed 11.0 =
  # June 2026). Two things come out of it:
  #
  # * #product_urls — the `/product/<slug>/` link set. The reconciliation
  #   pass in PublicationFetcher fetches any of these the site walk missed.
  # * #entries / #summary_for — one Entry per table row. The Summary fills
  #   the item's `abstract` when the product page has none.
  #
  # Table layouts:
  #
  # * `No | [N/I] | Date | Title | Ed | Summary` — recommendations,
  #   guidelines, manuals.
  # * `Ref. | Edition | Title` — model courses; the first Title line is the
  #   title, the lines below it are the summary.
  #
  # The PDF is landscape double-page: each half carries its own tables. A
  # text run belongs to the nearest table header above it in the same half;
  # the header runs give the column x-positions.
  class TechnicalCatalogue
    class NotFound < StandardError; end

    Entry = Struct.new(:code, :date, :title, :edition, :summary, keyword_init: true)

    # The Guidance & Publications page links the current catalogue PDF
    # (`/content/uploads/2026/08/Technical-documents-Catalogue-Ed-11.0-…pdf`).
    GUIDANCE_URL = "#{IalaFetcher::BASE_URL}/guidance-publications/".freeze
    LATEST_LINK = %r{https?://[^"'\s]*/Technical-documents-Catalogue-Ed-(\d+)\.(\d+)[^"'\s]*\.pdf}i
    PRODUCT_LINK = %r{\Ahttps?://(?:www\.)?iala(?:-aism\.org|-?\.int)/product/([^/?#]+)/?\z}i
    CODE = /\A[SRGCM]\d{4}(?:-\d+)?\z/
    # First header label → table kind.
    FIRST_LABELS = { "No" => :no, "Ref." => :ref }.freeze
    HEADER_LABELS = %w[N/I Date Title Ed Edition Summary].freeze
    # Values of the N/I (normative / informative) column.
    NI_VALUE = /\A(?:Nor|Inf)/i
    EDITION = /\A\d+\.\d+\z/
    # "Dec 2020", "Dec. 2021", "Dec2022", "June 2026".
    DATE = /\A[A-Z][a-z]{2,8}\.? ?\d{4}\z/
    # PDF control glyphs (bullets set as BEL, etc.).
    CONTROL_CHARS = /[\u0000-\u0008\u000b-\u001f]/
    # Table body text is set at 8 pt; section headings are 11 pt and up,
    # page numbers 7 pt.
    MIN_BODY_FONT_SIZE = 7.5
    MAX_BODY_FONT_SIZE = 9.5
    # Tolerance (pt) for aligning runs to header columns and lines.
    X_SLACK = 2.0

    Column = Struct.new(:name, :x)
    Table = Struct.new(:x, :y, :columns, :half, :kind)
    Row = Struct.new(:code, :y, :cells)
    Cell = Struct.new(:y, :x, :text)

    # The newest catalogue PDF linked from the Guidance & Publications
    # page. Picks the highest `Ed-<N>.<M>` edition.
    def self.latest_url(http_backend: IalaFetcher::Http.backend)
      html = http_backend.get(GUIDANCE_URL)
      best = html.to_enum(:scan, LATEST_LINK).map do
        m = Regexp.last_match
        [[m[1].to_i, m[2].to_i], m[0]]
      end.max_by(&:first)
      raise NotFound, "No Technical-documents-Catalogue-Ed-N.M PDF link at #{GUIDANCE_URL}" unless best

      best.last
    end

    # `IALA G1164 Ed 1.1 (E)` → code G1164, edition 1.1. Anchored, so
    # `IALA G1045 Annex Ed 1` (an annex, not G1045 itself) does not match.
    DOCID = /\AIALA ([SRGCM]\d{4}(?:-\d+)?)(?: Ed ([\d.]+))?(?: \([A-Z]\))?\z/i

    # [code, edition] from an item hash's primary docidentifier, or nil
    # (resolutions, annexes, codeless items). Edition is nil when absent.
    def self.primary_code(item_hash)
      docids = Array(item_hash["docidentifier"])
      docid = docids.find { |d| d["primary"] } || docids.first
      m = docid && docid["content"].to_s.strip.match(DOCID)
      m && [m[1].upcase, m[2]]
    end

    # "3" == "3.0" == "3.00"; "1.10" stays distinct from "1.1".
    def self.same_edition?(left, right)
      norm = ->(e) { e.to_s.split(".").map(&:to_i).reverse.drop_while(&:zero?).reverse }
      !left.to_s.empty? && !right.to_s.empty? && norm.(left) == norm.(right)
    end

    attr_reader :pdf_path

    def initialize(pdf_path)
      @pdf_path = pdf_path
    end

    # Distinct product page URLs on www.iala.int, in document order.
    # Search links (`?s=…`) and non-product paths are dropped.
    def product_urls
      @product_urls ||= link_uris.filter_map do |uri|
        slug = uri.strip[PRODUCT_LINK, 1]
        "#{IalaFetcher::BASE_URL}/product/#{slug.downcase}/" if slug
      end.uniq
    end

    def entries
      @entries ||= begin
        carry = nil
        pages.flat_map do |page|
          page_entries, carry = page_entries(page, carry)
          page_entries
        end
      end
    end

    # The Summary for +code+ at +edition+, or nil. The catalogue lists one
    # edition per code (the current one); a summary of another edition is
    # not this item's abstract. Codes repeat across the catalogue's domain
    # sections — the first entry wins.
    def summary_for(code, edition:)
      entry = first_entries[code.to_s.upcase]
      entry.summary if entry && self.class.same_edition?(entry.edition, edition)
    end

    private

    def reader
      @reader ||= PDF::Reader.new(@pdf_path)
    end

    PageRuns = Struct.new(:width, :runs)

    # Text runs of every page, read once.
    def pages
      @pages ||= reader.pages.map do |page|
        receiver = PDF::Reader::PageTextReceiver.new
        page.walk(receiver)
        PageRuns.new(page_width(page), receiver.runs)
      end
    end

    # Every lower-case word in the catalogue. A hyphen at a line end is a
    # soft break when the joined word occurs elsewhere (`provi-` + `ding`),
    # and a real compound otherwise (`man-` + `made`).
    def vocabulary
      @vocabulary ||= pages.flat_map(&:runs).each_with_object(Set.new) do |run, set|
        run.text.downcase.scan(/[[:alpha:]]+/) { |w| set << w }
      end
    end

    def first_entries
      @first_entries ||= entries.each_with_object({}) do |entry, acc|
        acc[entry.code] ||= entry
      end
    end

    def link_uris
      reader.pages.flat_map do |page|
        annots = reader.objects.deref!(page.attributes[:Annots]) || []
        annots.filter_map do |annot|
          next unless annot.is_a?(Hash)

          action = annot[:A]
          action[:URI] if action.is_a?(Hash) && action[:S] == :URI
        end
      end
    end

    # Halves are read in order (page 1 left, page 1 right, page 2 left …).
    # A table that runs past the end of a half with no new header keeps its
    # column layout in the next half: +carry+ is the last table seen.
    # Returns [entries, carry].
    def page_entries(page, carry)
      mid = page.width / 2.0
      runs = page.runs.select do |r|
        r.font_size.between?(MIN_BODY_FONT_SIZE, MAX_BODY_FONT_SIZE)
      end
      headers = []
      tables = find_tables(runs, mid, headers)
      body = runs - headers

      found = %i[left right].flat_map do |half|
        half_runs = body.select { |r| half_of(r, mid) == half }
        half_tables = tables.select { |t| t.half == half }
        continued = continued_table(carry, half_runs, half_tables, half)
        half_tables.unshift(continued) if continued
        carry = half_tables.min_by(&:y)

        by_table = half_runs.group_by { |run| owning_table(half_tables, run) }
        by_table.delete(nil)
        by_table.flat_map { |table, table_runs| table_entries(table, table_runs) }
      end
      [found, carry]
    end

    # +carry+ moved to this half's code column, when code runs sit above
    # every header here. Nil when the previous half had no table (index
    # pages, prose pages).
    def continued_table(carry, runs, tables, half)
      return nil unless carry

      top = tables.map(&:y).max || -Float::INFINITY
      first_code = runs.select { |r| r.y > top + X_SLACK && r.text.strip.match?(CODE) }
                       .max_by(&:y)
      return nil unless first_code

      dx = first_code.x - carry.x
      columns = carry.columns.map { |c| Column.new(c.name, c.x + dx) }
      Table.new(first_code.x, Float::INFINITY, columns, half, carry.kind)
    end

    def page_width(page)
      x0, _y0, x1, _y1 = reader.objects.deref!(page.attributes[:MediaBox])
      x1 - x0
    end

    def half_of(run, mid)
      run.x < mid ? :left : :right
    end

    # A table header is a "No" (or "Ref.") run followed, on the same line
    # and in the same half, by the other labels. A "No" table needs a
    # Summary column; a "Ref." table needs a Title column. The catalogue's
    # index lists (`G1112Ed1.1Title`) have no header at all. Header runs
    # are pushed onto +headers+ so they are not read as cell text.
    def find_tables(runs, mid, headers)
      runs.select { |r| FIRST_LABELS.key?(r.text.strip) }.filter_map do |first|
        kind = FIRST_LABELS.fetch(first.text.strip)
        half = half_of(first, mid)
        labels = runs.select do |r|
          HEADER_LABELS.include?(r.text.strip) && (r.y - first.y).abs <= X_SLACK &&
            r.x > first.x && half_of(r, mid) == half
        end
        next unless labels.map { |r| r.text.strip }.include?(kind == :ref ? "Title" : "Summary")

        headers.push(first, *labels)
        columns = [Column.new("No", first.x)] +
                  labels.sort_by(&:x).map { |r| Column.new(r.text.strip, r.x) }
        Table.new(first.x, first.y, columns, half, kind)
      end
    end

    # The nearest header above +run+ whose first column starts at or left
    # of the run.
    def owning_table(tables, run)
      tables
        .select { |t| t.y - run.y > X_SLACK && run.x + X_SLACK >= t.x }
        .min_by(&:y)
    end

    def table_entries(table, runs)
      rows = []
      runs.sort_by { |r| [-r.y.round, r.x] }.each do |run|
        column = column_for(table, run)
        text = run.text.strip
        next if text.empty?

        if column == "No"
          rows << Row.new(text, run.y, Hash.new { |h, k| h[k] = [] }) if text.match?(CODE)
          next
        end
        rows.last.cells[column] << Cell.new(run.y, run.x, text) if rows.last
      end
      rows.filter_map { |row| table.kind == :ref ? ref_entry(row) : no_entry(row) }
    end

    def column_for(table, run)
      table.columns.reverse.find { |c| c.x <= run.x + X_SLACK }&.name
    end

    # A row that leaves the N/I cell empty has its cells shifted one column
    # left: N/I holds the date and Date holds the start of the title.
    def no_entry(row)
      cells = row.cells
      date = cells["Date"]
      title = cells["Title"]
      ni = cells["N/I"]
      if ni.any? && !ni.first.text.match?(NI_VALUE)
        date = ni
        title = cells["Date"] + title
      end
      edition = cells["Ed"]
      # A narrow Ed column sometimes starts left of its header: the
      # edition then lands in the Title cell.
      edition, title = edition_from_title(title) if edition.empty?
      valid_entry(row, date: date, title: title, edition: edition, summary: cells["Summary"])
    end

    # Returns [edition_cells, title_cells]. The edition is either its own
    # Title-column run (`1.1`) or merged onto the end of one
    # (`Producing an IALA S-200 3.0`).
    def edition_from_title(title)
      edition = []
      rest = title.map do |cell|
        if cell.text.match?(EDITION)
          edition << cell
          next nil
        end
        if edition.empty? && (m = cell.text.match(/\A(.+?)\s+(\d+\.\d+)\z/))
          edition << Cell.new(cell.y, cell.x, m[2])
          next Cell.new(cell.y, cell.x, m[1])
        end
        cell
      end
      [edition, rest.compact]
    end

    # Rows that do not give a clean edition and date are other lists that
    # reuse a table header (revision lists, index pages) — drop them.
    def valid_entry(row, date:, title:, edition:, summary:)
      entry = Entry.new(code: row.code.upcase, date: join(date), title: join(title),
                        edition: join(edition), summary: join(summary))
      return nil if entry.summary.empty? || entry.title.empty?
      return nil unless entry.edition.match?(EDITION) && entry.date.match?(DATE)

      entry
    end

    # Model-course rows: `Ref. | Edition | Title`. The Title cell's first
    # line is the title; the lines below it are the summary. The Edition
    # cell holds `Ed3.0` over `Dec2022`.
    def ref_entry(row)
      first_line, rest = row.cells["Title"].partition { |c| (c.y - row.y).abs <= X_SLACK }
      edition, date = row.cells["Edition"].partition { |c| c.text.match?(/\AEd\s*\d/i) }
      edition = edition.map { |c| Cell.new(c.y, c.x, c.text.sub(/\AEd\s*/i, "")) }
      date = date.map { |c| Cell.new(c.y, c.x, c.text.sub(/\A([A-Za-z]+)(\d{4})\z/, '\1 \2')) }
      valid_entry(row, date: date, title: first_line, edition: edition, summary: rest)
    end

    # Join wrapped cell lines in reading order. A line that ends in a
    # hyphen joins without a space; the hyphen is dropped when it is a soft
    # break (see #vocabulary).
    def join(cells)
      return "" if cells.nil? || cells.empty?

      cells.sort_by { |c| [-c.y.round, c.x] }.each_with_object(+"") do |cell, acc|
        text = cell.text.gsub(CONTROL_CHARS, "").strip
        if (head = acc[/([[:alpha:]]+)-\z/, 1])
          tail = text[/\A[[:alpha:]]+/].to_s
          acc.chomp!("-") if vocabulary.include?("#{head}#{tail}".downcase)
        elsif !acc.empty?
          acc << " "
        end
        acc << text
      end.squeeze(" ").strip
    end
  end
end
