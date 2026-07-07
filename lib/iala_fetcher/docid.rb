# frozen_string_literal: true

module IalaFetcher
  # Immutable value object representing an IALA document identifier across
  # all its observed forms:
  #
  #   * bare catalogue code      — "S1070", "R0126", "C0103-1"
  #   * cover-page human form    — "IALA S1070 Ed 2.0", "R1016:ed2.0(F)"
  #   * WordPress listing cell   — "R1016:fr" (carries the language suffix)
  #   * MRN URN                  — "urn:mrn:iala:pub:s1070:ed2.0"
  #
  # Four constructors normalise the input grammars; accessors expose the
  # parsed fields; derived forms produce every shape downstream code needs
  # (id, filename stem, docid string, language-suffixed docid, URN).
  #
  # This is a self-contained value object for now. Once Pubid::Iala lands
  # in mn/pubid (see TODO.impl/00), the parsing logic here can be
  # delegated to Pubid::Iala::Identifier without changing the public API.
  class Docid
    LANGUAGE_LETTERS = %w[E F S C A R].freeze

    attr_reader :type_letter, :number, :subpart, :edition, :year, :language

    def initialize(type_letter:, number:, subpart: nil, edition: nil,
                   year: nil, language: nil)
      @type_letter = type_letter
      @number = number
      @subpart = subpart
      @edition = edition
      @year = year
      @language = language
      freeze
    end

    # --- Constructors (one per input grammar) ---

    # Parses a bare catalogue code or cover-page form. Accepts:
    #   "S1070"
    #   "S1070 Ed 2.0"
    #   "IALA S1070 Ed 2.0"
    #   "R0126:ed2.0"
    #   "R1016:ed2.0(F)"
    def self.from_code(str)
      parse_canonical(str)
    end

    def self.from_cover(str)
      from_code(str)
    end

    # Parses the WordPress listing cell form, which carries a `:fr`/`:es`
    # suffix indicating the language category the row came from. Returns
    # a Docid with `language` set from the suffix.
    #
    #   "R1016"        → language nil (English default)
    #   "R1016:fr"     → language "F"
    #   "R1016:es"     → language "S"
    def self.from_listing_cell(str)
      code, lang_tag = str.split(":", 2)
      docid = parse_canonical(code)
      return docid unless lang_tag

      lang_letter = decode_listing_language(lang_tag)
      docid.with_language(lang_letter)
    end

    # Parses an MRN URN.
    #   "urn:mrn:iala:pub:s1070:ed2.0"
    #   "urn:mrn:iala:pub:s1070:ed2.0:fr"
    def self.from_urn(urn)
      raise ArgumentError, "Not an IALA URN: #{urn.inspect}" unless urn.start_with?("urn:mrn:iala:pub:")

      body = urn.sub(/\Aurn:mrn:iala:pub:/, "")
      parts = body.split(":")
      code = parts.shift
      edition = nil
      language = nil
      parts.each do |seg|
        if seg.start_with?("ed")
          edition = seg.sub(/\Aed/, "")
        elsif seg.length == 1 && seg =~ /\A[a-z]\z/i
          language = seg.upcase
        end
      end
      docid = parse_canonical(code)
      docid = docid.with_edition(edition) if edition
      docid = docid.with_language(language) if language
      docid
    end

    # --- Derived forms ---

    def to_s
      base = "IALA #{core}"
      base += " Ed #{edition}" if edition
      base += " (#{language})" if language
      base
    end

    # The relaton `id` field — work-level ids never carry a language
    # suffix; instance ids append the single-letter code with a dash.
    def id
      bits = [core_with_edition]
      bits << language if language
      bits.join("-")
    end

    def filename_stem
      id.downcase.tr(" ", "_").gsub("/", "-")
    end

    def urn
      parts = ["urn:mrn:iala:pub", core.downcase]
      parts << "ed#{edition}" if edition
      parts << language.downcase if language
      parts.join(":")
    end

    # --- Mutators (return new instances; objects are frozen) ---

    def with_language(lang_letter)
      validate_language!(lang_letter)
      self.class.new(
        type_letter: type_letter, number: number, subpart: subpart,
        edition: edition, year: year, language: lang_letter,
      )
    end

    def with_edition(ed)
      self.class.new(
        type_letter: type_letter, number: number, subpart: subpart,
        edition: ed, year: year, language: language,
      )
    end

    def work
      self.class.new(
        type_letter: type_letter, number: number, subpart: subpart,
        edition: edition, year: year, language: nil,
      )
    end

    def ==(other)
      other.is_a?(Docid) &&
        other.type_letter == type_letter &&
        other.number == number &&
        other.subpart == subpart &&
        other.edition == edition &&
        other.year == year &&
        other.language == language
    end

    # --- Internals ---

    # The bare code without language or edition, e.g. "S1070", "C0103-1".
    def core
      subpart ? "#{type_letter}#{number}-#{subpart}" : "#{type_letter}#{number}"
    end

    private

    def core_with_edition
      return core unless edition

      "#{core}-#{edition}"
    end

    def validate_language!(letter)
      return if LANGUAGE_LETTERS.include?(letter)

      raise ArgumentError, "Unknown IALA language letter: #{letter.inspect}"
    end

    class << self
      private

      # rubocop:disable Metrics/MethodLength
      def parse_canonical(str)
        s = str.to_s.strip
        s = s.sub(/\AIALA\s+/i, "")

        # Extract optional (X) language suffix at end.
        lang = nil
        if (m = s.match(/\((#{LANGUAGE_LETTERS.join("|")})\)\s*\z/i))
          lang = m[1].upcase
          s = m.pre_match.strip
        end

        # Extract optional "Ed X.Y" or ":edX.Y" edition.
        edition = nil
        if (m = s.match(/\A(.+?)\s+Ed\s+([\d.]+)\z/i))
          s = m[1]
          edition = m[2]
        elsif (m = s.match(/\A(.+?):ed([\d.]+)\z/i))
          s = m[1]
          edition = m[2]
        end

        # What remains is the bare code: letter + digits + optional subpart.
        unless (m = s.match(/\A([A-Z])(\d+)(?:-(\d+(?:-\d+)*))?\z/i))
          raise ArgumentError, "Unrecognized IALA code: #{str.inspect}"
        end

        type_letter = m[1].upcase
        number = m[2]
        subpart = m[3]

        new(
          type_letter: type_letter, number: number, subpart: subpart,
          edition: edition, year: nil, language: lang,
        )
      end
      # rubocop:enable Metrics/MethodLength

      # WordPress listing suffix → IALA cover-page letter code.
      #   "fr" → "F", "es" → "S", "en" → "E"
      def decode_listing_language(suffix)
        case suffix.to_s.downcase
        when "en", "eng" then "E"
        when "fr", "fra", "french" then "F"
        when "es", "spa", "spanish" then "S"
        when "cn", "zho", "chinese" then "C"
        when "ar", "ara", "arabic" then "A"
        when "ru", "rus", "russian" then "R"
        else
          raise ArgumentError, "Unknown IALA listing language suffix: #{suffix.inspect}"
        end
      end
    end
  end
end
