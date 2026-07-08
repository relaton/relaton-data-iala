# frozen_string_literal: true

module IalaFetcher
  # Immutable value object representing an IALA document identifier across
  # all its observed forms:
  #
  #   * bare catalogue code      — "S1070", "R0126", "C0103-1"
  #   * cover-page human form    — "IALA S1070 Ed 2.0", "R1016:ed2.0(F)"
  #   * WordPress listing cell   — "R1016:fr" (carries the language suffix)
  #   * MRN URN                  — "urn:mrn:iala:pub:s1070:ed2.0"
  #   * resolution code          — "GA01.13 (EN)", "G01.012"
  #   * slug-derived code        — "report-on-the-workshop-..." (codeless items)
  #
  # Two flavours of Docid exist internally:
  #
  #   * typed   — the code matches S/R/G/M/C/<letter><digits>[-<subpart>]
  #               and supports URN generation.
  #   * generic — the code is an opaque string (resolution number, slug).
  #               No URN is generated; `id`/`filename_stem`/`to_s` still
  #               work.
  #
  # Constructors normalise the input grammars; accessors expose the
  # parsed fields; derived forms produce every shape downstream code needs
  # (id, filename stem, docid string, language-suffixed docid, URN).
  class Docid
    LANGUAGE_LETTERS = %w[E F S C A R].freeze
    # Codes that begin with one of these letters (followed by digits) are
    # treated as typed IALA identifiers. Anything else falls through to
    # the generic path.
    TYPED_PREFIX = /\A[S R G M C X P L V]\d/i.freeze

    attr_reader :code, :edition, :language, :typed, :doctype

    def initialize(code:, edition: nil, language: nil, typed: true, doctype: nil)
      @code = code
      @edition = edition
      @language = language
      @typed = typed
      @doctype = doctype
      freeze
    end

    # --- Constructors (one per input grammar) ---

    # Parses a bare catalogue code or cover-page form. Accepts:
    #   "S1070"
    #   "S1070 Ed 2.0"
    #   "IALA S1070 Ed 2.0"
    #   "R0126:ed2.0"
    #   "R1016:ed2.0(F)"
    # Raises ArgumentError if the code doesn't match a typed IALA shape.
    def self.from_code(str)
      parse_typed(str)
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
      code, lang_tag = str.to_s.split(":", 2)
      docid = parse_any(code)
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
      docid = parse_any(code)
      docid = docid.with_edition(edition) if edition
      docid = docid.with_language(language) if language
      docid
    end

    # Builds a generic Docid from an opaque identifier (resolution number,
    # slug-derived id, etc.). The `typed` flag is false; URN generation
    # returns nil.
    def self.from_natural_key(str, doctype: nil)
      parse_any(str.to_s, doctype: doctype)
    end

    # Builds a Docid for a codeless item by deriving a stable id from the
    # product URL slug. E.g.
    #   "https://www.iala.int/product/report-on-the-workshop-on-foo/"
    #   → code "report-on-the-workshop-on-foo"
    def self.from_product_url(url, doctype: nil)
      slug = url.to_s.sub(%r{/\z}, "").sub(%r{.*/product/}, "")
      return new(code: "untitled", typed: false, doctype: doctype) if slug.empty?

      new(code: slug, typed: false, doctype: doctype)
    end

    # --- Derived forms ---

    def to_s
      base = "IALA #{code}"
      base += " Ed #{edition}" if edition
      base += " (#{language})" if language
      base
    end

    # The relaton `id` field — work-level ids never carry a language
    # suffix; instance ids append the single-letter code with a dash.
    def id
      bits = [code_with_edition]
      bits << language if language
      bits.join("-")
    end

    def filename_stem
      id.downcase
         .tr(" ", "_")
         .gsub("/", "-")
         .gsub(/[^a-z0-9_.-]/, "")
         .gsub(/_+/, "_")
         .gsub(/-+/, "-")
    end

    # Typed Docids emit MRN URNs; generic ones return nil.
    def urn
      return nil unless typed

      parts = ["urn:mrn:iala:pub", code.downcase]
      parts << "ed#{edition}" if edition
      parts << language.downcase if language
      parts.join(":")
    end

    # --- Mutators (return new instances; objects are frozen) ---

    def with_language(lang_letter)
      validate_language!(lang_letter)
      self.class.new(
        code: code, edition: edition, language: lang_letter,
        typed: typed, doctype: doctype,
      )
    end

    def with_edition(ed)
      self.class.new(
        code: code, edition: ed, language: language,
        typed: typed, doctype: doctype,
      )
    end

    def work
      self.class.new(
        code: code, edition: edition, language: nil,
        typed: typed, doctype: doctype,
      )
    end

    def ==(other)
      other.is_a?(Docid) &&
        other.code == code &&
        other.edition == edition &&
        other.language == language &&
        other.typed == typed &&
        other.doctype == doctype
    end

    # Back-compat accessor: for typed Docids, the leading letter.
    def type_letter
      return nil unless typed

      code[%r{\A([A-Z])}i, 1]&.upcase
    end

    private

    def code_with_edition
      return code unless edition

      "#{code}-#{edition}"
    end

    def validate_language!(letter)
      return if LANGUAGE_LETTERS.include?(letter)

      raise ArgumentError, "Unknown IALA language letter: #{letter.inspect}"
    end

    class << self
      private

      # rubocop:disable Metrics/MethodLength
      # Try typed first; on failure fall back to a generic docid. `doctype`
      # is only attached to generic docids (typed ones infer it from the
      # type_letter at the fetcher layer).
      def parse_any(str, doctype: nil)
        return new(code: "", typed: false, doctype: doctype) if str.to_s.strip.empty?

        begin
          parse_typed(str)
        rescue ArgumentError
          stripped = strip_resolution_language_suffix(str.to_s.strip)
          stripped = normalise_code(stripped)
          new(code: stripped, typed: false, doctype: doctype)
        end
      end

      # Strip leading zeros from every numeric run and fix the G01 → GA01
      # typo on General Assembly resolutions. Idempotent.
      def normalise_code(code)
        s = code.to_s.dup
        s = "GA" + s[1..] if s.start_with?("G0")
        s.gsub(/(\d+)/) { |m| m.to_i.to_s }
      end

      def parse_typed(str)
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
        number = m[2].sub(/\A0+(\d)/, '\1')  # strip leading zeros
        subpart = m[3]
        code = subpart ? "#{type_letter}#{number}-#{subpart}" : "#{type_letter}#{number}"

        new(
          code: code, edition: edition, language: lang,
          typed: true, doctype: nil,
        )
      end
      # rubocop:enable Metrics/MethodLength

      # Strips the trailing "(EN)"/"(FR)" suffix that resolution codes
      # carry on the listing cell. The language itself is recorded
      # separately via the category slug.
      def strip_resolution_language_suffix(str)
        str.sub(/\s*\((?:EN|FR|ES|AR|CN|RU)\)\s*\z/i, "")
      end

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
