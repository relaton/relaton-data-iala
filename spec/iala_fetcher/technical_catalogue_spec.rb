# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require_relative "../support/pdf_builder"

RSpec.describe IalaFetcher::TechnicalCatalogue do
  let(:tmp_dir) { File.expand_path("../tmp/technical_catalogue_spec", __dir__) }
  let(:pdf_path) { File.join(tmp_dir, "catalogue.pdf") }

  # Mirrors the real Ed 11.0 layout: a landscape spread with one table per
  # half. The left table has the optional N/I column.
  let(:runs) do
    [
      # Left half — header + two rows (R0106 wraps over three lines).
      [57.9, 430.9, "No"], [91.9, 430.9, "N/I"], [125.9, 430.9, "Date"],
      [159.9, 430.9, "Title"], [222.3, 430.9, "Ed"], [244.9, 430.9, "Summary"],
      [57.9, 416.9, "R0106"], [91.9, 416.9, "Nor"], [125.9, 416.9, "Jun"],
      [159.9, 416.9, "Retroreflecting"], [222.3, 416.9, "2.1"],
      [244.9, 416.9, "Recommends the use of the"],
      [125.9, 408.2, "2017"], [159.9, 408.2, "Material"],
      [244.9, 408.2, "standard code for"],
      [244.9, 399.6, "retroreflective material."],
      [57.9, 380.0, "C0103-1"], [125.9, 380.0, "Dec"],
      [159.9, 380.0, "Level 1 AtoN"], [222.3, 380.0, "1.0"],
      [244.9, 380.0, "Model course for AtoN managers."],
      [125.9, 371.4, "2020"], [159.9, 371.4, "Manager"],
      # Right half — header without N/I, one row.
      [478.8, 459.4, "No"], [512.8, 459.4, "Date"], [548.3, 459.4, "Title"],
      [644.6, 459.4, "Ed"], [667.3, 459.4, "Summary"],
      [478.8, 445.4, "G1116"], [512.8, 445.4, "Dec"],
      [548.3, 445.4, "Selection of Rhythmic"], [644.6, 445.4, "1.1"],
      [667.3, 445.4, "Guidance on rhythmic"],
      [512.8, 436.8, "2016"], [548.3, 436.8, "Characters"],
      [667.3, 436.8, "characters."],
    ]
  end

  let(:uris) do
    [
      "https://www.iala.int/product/g1164/",
      "https://www.iala-aism.org/product/g1041/",
      "https://www.iala-.int/product/c0103-1/",
      "https://www.iala.int/product/G1164/",
      "https://www.iala.int/product-category/publications/?s=C2011-1&post_type=product",
      "https://www.iala.int/c0103-3/",
    ]
  end

  before do
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    PdfBuilder.new
      .page(runs: runs, uris: uris)
      .page(runs: [
              # A second table that repeats G1116 — the first summary wins.
              [57.9, 500.0, "No"], [91.9, 500.0, "Date"], [125.9, 500.0, "Title"],
              [222.3, 500.0, "Ed"], [244.9, 500.0, "Summary"],
              [57.9, 490.0, "G1116"], [91.9, 490.0, "Dec 2016"],
              [125.9, 490.0, "Selection"], [222.3, 490.0, "1.1"],
              [244.9, 490.0, "A different summary."],
              # An index-list line (no table header above it): ignored.
              [480.0, 300.0, "G1112Ed1.1Performance and Monitoring"],
            ])
      .write(pdf_path)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  subject(:catalogue) { described_class.new(pdf_path) }

  describe "#product_urls" do
    it "normalises hosts to www.iala.int and keeps only /product/<slug>/ links" do
      expect(catalogue.product_urls).to eq([
        "https://www.iala.int/product/g1164/",
        "https://www.iala.int/product/g1041/",
        "https://www.iala.int/product/c0103-1/",
      ])
    end
  end

  describe "#entries" do
    it "parses each table row into code, date, title, edition, summary" do
      r0106 = catalogue.entries.find { |e| e.code == "R0106" }
      expect(r0106.date).to eq("Jun 2017")
      expect(r0106.title).to eq("Retroreflecting Material")
      expect(r0106.edition).to eq("2.1")
      expect(r0106.summary).to eq(
        "Recommends the use of the standard code for retroreflective material.",
      )
    end

    it "parses part codes and tables without the N/I column" do
      expect(catalogue.entries.map(&:code)).to include("C0103-1", "G1116")
      expect(catalogue.summary_for("G1116", edition: "1.1")).to eq("Guidance on rhythmic characters.")
    end

    it "ignores lines that are not under a table header" do
      expect(catalogue.entries.map(&:code)).not_to include("G1112")
    end
  end

  describe "#summary_for" do
    it "keeps the first summary when a code repeats in another table" do
      expect(catalogue.summary_for("G1116", edition: "1.1")).to eq("Guidance on rhythmic characters.")
    end

    it "matches codes case-insensitively and returns nil for unknown codes" do
      expect(catalogue.summary_for("r0106", edition: "2.1")).to start_with("Recommends")
      expect(catalogue.summary_for("S9999", edition: "1.0")).to be_nil
    end

    it "returns nil for another edition, and treats 2 and 2.1.0 forms by value" do
      expect(catalogue.summary_for("R0106", edition: "2.0")).to be_nil
      expect(catalogue.summary_for("R0106", edition: nil)).to be_nil
      expect(catalogue.summary_for("C0103-1", edition: "1")).to start_with("Model course")
      expect(catalogue.summary_for("R0106", edition: "2.1.0")).to start_with("Recommends")
    end
  end

  describe ".primary_code" do
    def item(docid)
      { "docidentifier" => [{ "content" => docid, "type" => "IALA", "primary" => true }] }
    end

    it "reads code and edition from Work and Instance docids" do
      expect(described_class.primary_code(item("IALA G1164 Ed 1.1"))).to eq(["G1164", "1.1"])
      expect(described_class.primary_code(item("IALA C0103-1 Ed 3.0 (E)"))).to eq(["C0103-1", "3.0"])
      expect(described_class.primary_code(item("IALA G1081 (S)"))).to eq(["G1081", nil])
    end

    it "does not match annexes, resolutions or codeless items" do
      expect(described_class.primary_code(item("IALA G1045 Annex Ed 1"))).to be_nil
      expect(described_class.primary_code(item("IALA G1128 Annex A Ed 1.6 (E)"))).to be_nil
      expect(described_class.primary_code(item("IALA GA01.13"))).to be_nil
      expect(described_class.primary_code(item("IALA floataid-workshop"))).to be_nil
    end
  end

  describe "layout variants" do
    let(:variants_path) { File.join(tmp_dir, "variants.pdf") }

    before do
      PdfBuilder.new
        .page(runs: [
                # Left: N/I table. G1173 leaves N/I empty, so its cells sit
                # one column left. G1163's edition starts left of "Ed".
                [57.9, 500.0, "No"], [91.9, 500.0, "N/I"], [125.9, 500.0, "Date"],
                [159.9, 500.0, "Title"], [222.3, 500.0, "Ed"], [244.9, 500.0, "Summary"],
                [57.9, 486.0, "G1173"], [92.3, 486.0, "Dec"], [126.0, 486.0, "Marine AtoN Aware-"],
                [221.4, 486.0, "1.0"], [243.9, 486.0, "Enhances mariners' understan-"],
                [92.3, 477.4, "2022"], [126.0, 477.4, "ness"], [243.9, 477.4, "ding of man-"],
                [243.9, 468.8, "made AtoN. Understanding awareness matters."],
                [57.9, 450.0, "G1163"], [91.9, 450.0, "Nor"], [125.9, 450.0, "Dec"],
                [159.9, 450.0, "Breakwaters"], [216.0, 450.0, "1.1"],
                [244.9, 450.0, "Guidance on breakwaters."],
                [125.9, 441.4, "2021"],
                # Bottom of the left half: a row with no header on the next half.
                [57.9, 60.0, "G1105"], [91.9, 60.0, "Nor"], [125.9, 60.0, "Jun"],
                [159.9, 60.0, "S-200 3.0"], [244.9, 60.0, "Guidance on S-200."],
                [125.9, 51.4, "2025"],
                # Right: continuation of the left table, no header.
                [478.8, 540.0, "G1106"], [512.8, 540.0, "Nor"], [546.8, 540.0, "Jun"],
                [580.9, 540.0, "IALA S-200 3.0"], [665.9, 540.0, "Guidance on an overview."],
                [546.8, 531.4, "2025"], [580.9, 531.4, "Product Spec"],
                # Right: model-course table.
                [478.0, 339.7, "Ref."], [537.5, 339.7, "Edition"], [571.5, 339.7, "Title"],
                [478.0, 325.5, "C0103-1"], [537.5, 325.5, "Ed3.0"], [571.5, 325.5, "VTS Operators Training"],
                [537.5, 317.5, "Dec2022"],
                [571.5, 314.0, "The purpose of this model course is to assist"],
                [571.5, 305.4, "training organizations."],
                # Right: a revision list under a "No" header — no date or edition.
                [478.8, 200.0, "No"], [512.8, 200.0, "Date"], [580.9, 200.0, "Title"],
                [643.2, 200.0, "Ed"], [665.9, 200.0, "Summary"],
                [478.8, 186.0, "R0108"], [580.9, 186.0, "Surface Colours"], [665.9, 186.0, "to Navigation"],
              ])
        .page(runs: [[777.9, 17.0, "57"]], font_size: 7)
        .write(variants_path)
    end

    subject(:variants) { described_class.new(variants_path) }

    def entry(code)
      variants.entries.find { |e| e.code == code }
    end

    it "reads a row whose N/I cell is empty" do
      expect(entry("G1173").to_h).to include(date: "Dec 2022", title: "Marine AtoN Awareness",
                                             edition: "1.0")
    end

    it "drops soft hyphens and keeps compound hyphens at line ends" do
      expect(entry("G1173").summary).to eq(
        "Enhances mariners' understanding of man-made AtoN. Understanding awareness matters.",
      )
    end

    it "recovers an edition placed in the Title column or merged onto the title" do
      expect(entry("G1163").to_h).to include(title: "Breakwaters", edition: "1.1")
      expect(entry("G1105").to_h).to include(title: "S-200", edition: "3.0")
    end

    it "continues a table into the next half when no header repeats" do
      expect(entry("G1106").to_h).to include(
        date: "Jun 2025", title: "IALA S-200 Product Spec",
        edition: "3.0", summary: "Guidance on an overview."
      )
    end

    it "parses model-course tables (Ref. | Edition | Title)" do
      expect(entry("C0103-1").to_h).to eq(
        code: "C0103-1", date: "Dec 2022", title: "VTS Operators Training", edition: "3.0",
        summary: "The purpose of this model course is to assist training organizations.",
      )
    end

    it "drops rows without a clean date and edition" do
      expect(entry("R0108")).to be_nil
    end
  end

  describe ".latest_url" do
    let(:guidance_url) { "https://www.iala.int/guidance-publications/" }

    def backend(html)
      IalaFetcher::Http::Fake.new(guidance_url => html)
    end

    it "picks the catalogue PDF link with the highest edition" do
      html = <<~HTML
        <a href="https://www.iala.int/content/uploads/2026/02/Technical-documents-Catalogue-Ed-10.0-December-2025-03.02.2026.pdf">10</a>
        <a href="https://www.iala.int/content/uploads/2026/08/Technical-documents-Catalogue-Ed-11.0-June-2026-DoublePage.pdf">11</a>
        <a href="https://www.iala.int/content/uploads/2025/03/Technical-documents-Catalogue-Ed-9.2-March.pdf">9.2</a>
        <a href="https://www.iala.int/guidance-publications/technical-documents-catalogue-ed-12-0-attachment/">not a PDF</a>
      HTML
      expect(described_class.latest_url(http_backend: backend(html))).to eq(
        "https://www.iala.int/content/uploads/2026/08/Technical-documents-Catalogue-Ed-11.0-June-2026-DoublePage.pdf",
      )
    end

    it "raises when the page has no edition-numbered catalogue PDF link" do
      expect { described_class.latest_url(http_backend: backend("<p>none</p>")) }
        .to raise_error(IalaFetcher::TechnicalCatalogue::NotFound)
    end
  end
end
