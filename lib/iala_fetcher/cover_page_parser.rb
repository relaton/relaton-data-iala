# frozen_string_literal: true

module IalaFetcher
  # Parses the cover-page text of an IALA PDF into structured fields.
  #
  # The canonical IALA cover-page layout (verified against S1020, S1070):
  #
  #   IALA STANDARD
  #
  #   S1070
  #   INFORMATION SERVICES
  #
  #   Edition 2.0
  #   June 2023
  #
  #   urn:mrn:iala:pub:s1070:ed2.0
  #
  # Older documents may omit the URN line or use a different label
  # ("IALA RECOMMENDATION", "IALA GUIDELINE", etc.).
  class CoverPageParser
    Result = Struct.new(
      :label, :code, :title, :edition, :month_year, :urn, :doctype,
      keyword_init: true,
    )

    class MissingCoverFields < StandardError; end

    MONTHS = %w[
      January February March April May June July
      August September October November December
    ].freeze

    def self.parse(text)
      new(text).parse
    end

    def initialize(text)
      @text = text.to_s
      @lines = @text.lines.map(&:strip).reject(&:empty?)
    end

    def parse
      raise MissingCoverFields, "no text to parse" if @lines.empty?

      Result.new(
        label: label,
        code: code,
        title: title,
        edition: edition,
        month_year: month_year,
        urn: urn,
        doctype: doctype,
      )
    end

    private

    def label
      @lines.each do |line|
        m = line.match(/\AIALA\s+(STANDARD|RECOMMENDATION|GUIDELINE|MANUAL|MODEL\s+COURSE)\z/i)
        return "IALA " + m[1].upcase.sub(/\s+/, " ") if m
      end
      nil
    end

    def doctype
      return nil unless label

      key = label.sub(/\AIALA\s+/, "").upcase
      IalaFetcher::COVER_LABEL_TO_DOCTYPE.fetch(key) do |k|
        warn "Unknown cover label: #{k.inspect}" if k
        nil
      end
    end

    def code
      @lines.each do |line|
        return line.upcase if line.match?(/\A[A-Z]\d{4}(?:-\d+)*\z/i)
      end
      nil
    end

    # The title is everything between the code line and the next blank
    # or anchor line ("Edition", "Month Year", "urn:"). Since `@lines`
    # already strips blanks, we slice between the code index and the
    # index of the first anchor line.
    def title
      code_idx = @lines.index { |l| l.match?(/\A[A-Z]\d{4}(?:-\d+)*\z/i) }
      return nil unless code_idx

      slice = @lines[(code_idx + 1)..].take_while { |l| !anchor_line?(l) }
      title = slice.join(" ").strip
      title.empty? ? nil : title
    end

    def anchor_line?(line)
      line.match?(/\AEdition\s+[\d.]+\z/i) ||
        line.match?(/\A(#{MONTHS.join("|")})\s+\d{4}\z/) ||
        line.match?(/\Aurn:mrn:iala:pub:/i)
    end

    def edition
      @lines.each do |line|
        m = line.match(/\AEdition\s+([\d.]+)\z/i)
        return m[1] if m
      end
      nil
    end

    def month_year
      @lines.each do |line|
        m = line.match(/\A(#{MONTHS.join("|")})\s+(\d{4})\z/)
        return "#{m[1]} #{m[2]}" if m
      end
      nil
    end

    def urn
      @lines.each do |line|
        return line.strip if line.match?(/\Aurn:mrn:iala:pub:/i)
      end
      nil
    end
  end
end
