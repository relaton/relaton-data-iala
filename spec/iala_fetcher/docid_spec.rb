# frozen_string_literal: true

require "spec_helper"
require "date"

RSpec.describe IalaFetcher::Docid do
  describe ".from_code" do
    it "parses a bare catalogue code" do
      d = described_class.from_code("S1070")
      expect(d.to_s).to eq("IALA S1070")
      expect(d.id).to eq("S1070")
      expect(d.filename_stem).to eq("s1070")
      expect(d.urn).to eq("urn:mrn:iala:pub:s1070")
    end

    it "parses a code with edition (cover form)" do
      d = described_class.from_code("IALA S1070 Ed 2.0")
      expect(d.to_s).to eq("IALA S1070 Ed 2.0")
      expect(d.id).to eq("S1070-2.0")
      expect(d.filename_stem).to eq("s1070-2.0")
      expect(d.urn).to eq("urn:mrn:iala:pub:s1070:ed2.0")
    end

    it "parses the compact listing form (stripping leading zeros)" do
      d = described_class.from_code("R0126:ed2.0")
      expect(d.to_s).to eq("IALA R126 Ed 2.0")
      expect(d.id).to eq("R126-2.0")
    end

    it "normalises zero-padded numbers (M0001 → M1, C0103-1 → C103-1)" do
      expect(described_class.from_code("M0001").id).to eq("M1")
      expect(described_class.from_code("C0103-1 Ed 3.0").id).to eq("C103-1-3.0")
    end

    it "parses a code with language" do
      d = described_class.from_code("R1016:ed2.0(F)")
      expect(d.language).to eq("F")
      expect(d.id).to eq("R1016-2.0-F")
      expect(d.filename_stem).to eq("r1016-2.0-f")
    end

    it "preserves a numeric subpart (with normalised base)" do
      d = described_class.from_code("C0103-1 Ed 3.0")
      expect(d.to_s).to eq("IALA C103-1 Ed 3.0")
      expect(d.id).to eq("C103-1-3.0")
      expect(d.urn).to eq("urn:mrn:iala:pub:c103-1:ed3.0")
    end

    it "raises on unrecognised input" do
      expect { described_class.from_code("XYZ-not-a-code") }
        .to raise_error(ArgumentError)
    end
  end

  describe ".from_listing_cell" do
    it "strips the :fr suffix into language F" do
      d = described_class.from_listing_cell("R1016:fr")
      expect(d.language).to eq("F")
      expect(d.to_s).to eq("IALA R1016 (F)")
    end

    it "strips the :es suffix into language S" do
      d = described_class.from_listing_cell("R1016:es")
      expect(d.language).to eq("S")
    end

    it "returns a work-only docid when there is no language suffix" do
      d = described_class.from_listing_cell("R1016")
      expect(d.language).to be_nil
    end
  end

  describe ".from_urn" do
    it "parses a cover-page URN" do
      d = described_class.from_urn("urn:mrn:iala:pub:s1070:ed2.0")
      expect(d.to_s).to eq("IALA S1070 Ed 2.0")
      expect(d.id).to eq("S1070-2.0")
    end

    it "parses a URN with language" do
      d = described_class.from_urn("urn:mrn:iala:pub:r1016:ed2.0:f")
      expect(d.to_s).to eq("IALA R1016 Ed 2.0 (F)")
      expect(d.language).to eq("F")
    end

    it "raises on a non-IALA URN" do
      expect { described_class.from_urn("urn:iho:s:44:5.0.0") }
        .to raise_error(ArgumentError)
    end
  end

  describe "#with_language / #work" do
    it "returns a new instance with the language set" do
      d = described_class.from_code("S1070 Ed 2.0").with_language("F")
      expect(d.language).to eq("F")
      expect(d.id).to eq("S1070-2.0-F")
    end

    it "rejects an unknown language letter" do
      expect { described_class.from_code("S1070").with_language("Z") }
        .to raise_error(ArgumentError)
    end

    it "strips the language on #work" do
      d = described_class.from_code("R1016:ed2.0(F)").work
      expect(d.language).to be_nil
      expect(d.to_s).to eq("IALA R1016 Ed 2.0")
    end
  end

  describe "#==" do
    it "is equal when all fields match" do
      a = described_class.from_code("S1070 Ed 2.0")
      b = described_class.from_code("S1070 Ed 2.0")
      expect(a).to eq(b)
    end

    it "is unequal when the language differs" do
      a = described_class.from_code("S1070 Ed 2.0")
      b = described_class.from_code("S1070 Ed 2.0").with_language("F")
      expect(a).not_to eq(b)
    end
  end
end
