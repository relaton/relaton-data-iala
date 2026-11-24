# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require_relative "../support/pdf_builder"

RSpec.describe IalaFetcher::PublicationFetcher, "with a TechnicalCatalogue" do
  let(:tmp_dir) { File.expand_path("../tmp/publication_fetcher_catalogue_spec", __dir__) }
  let(:data_dir) { File.join(tmp_dir, "data") }
  let(:pdf_path) { File.join(tmp_dir, "catalogue.pdf") }

  def fixture(name)
    File.read(File.expand_path("../fixtures/iala/#{name}", __dir__), encoding: "UTF-8")
  end

  let(:s1070_alias) { "https://www.iala.int/product/s1070-information-services/" }
  let(:http_backend) do
    IalaFetcher::Http::Fake.new(
      "https://www.iala.int/product-category/publications/standards/" => fixture("standards.html"),
      "https://www.iala.int/product-category/publications/guidelines/" => "<html><body></body></html>",
      "https://www.iala.int/product/s1070/" => fixture("product_s1070.html"),
      # A legacy catalogue slug for a product the site walk already has.
      s1070_alias => fixture("product_s1070.html"),
      "https://www.iala.int/product/g1164/" => fixture("product_g1164.html"),
    )
  end

  let(:catalogue) do
    PdfBuilder.new
      .page(
        runs: [
          [57.9, 500.0, "No"], [91.9, 500.0, "Date"], [140.0, 500.0, "Title"],
          [222.3, 500.0, "Ed"], [244.9, 500.0, "Summary"],
          [57.9, 486.0, "G1164"], [91.9, 486.0, "Dec 2021"], [140.0, 486.0, "MRN OIDs"],
          [222.3, 486.0, "1.1"], [244.9, 486.0, "Guidance on MRN organisation identifiers."],
          [57.9, 470.0, "S1070"], [91.9, 470.0, "Jun 2023"], [140.0, 470.0, "Info Services"],
          [222.3, 470.0, "2.0"], [244.9, 470.0, "Catalogue summary of S1070."],
        ],
        uris: [
          "https://www.iala.int/product/s1070/",
          "https://www.iala-aism.org/product/g1164/",
          s1070_alias,
        ],
      )
      .write(pdf_path)
    IalaFetcher::TechnicalCatalogue.new(pdf_path)
  end

  let(:store) { IalaFetcher::YamlStore.new(data_dir) }

  def fetcher(categories: %w[standards guidelines], technical_catalogue: catalogue)
    described_class.new(
      data_dir: data_dir, yaml_store: store, categories: categories,
      http_backend: http_backend, technical_catalogue: technical_catalogue
    )
  end

  def yaml(name)
    store.read(name)
  end

  def files
    Dir[File.join(data_dir, "*.yaml")].map { |f| File.basename(f, ".yaml") }.sort
  end

  around do |ex|
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    ex.run
    FileUtils.rm_rf(tmp_dir)
  end

  describe "#run" do
    it "fetches a catalogue product the site walk missed" do
      fetcher.run
      expect(files).to include("g1164-1.1", "g1164-1.1-e")
      work = yaml("g1164-1.1")
      expect(work["docidentifier"].first["content"]).to eq("IALA G1164 Ed 1.1")
      expect(work["ext"]["doctype"]["content"]).to eq("guideline")
      expect(work["ext"]["webpage"]).to eq("https://www.iala.int/product/g1164/")
    end

    it "does not emit a second item for a known code behind another slug" do
      fetcher.run
      expect(files.grep(/\As1070/)).to contain_exactly("s1070-2.0", "s1070-2.0-e")
    end

    it "fills the English abstract from the catalogue summary" do
      fetcher.run
      expected = [{
        "content" => "Guidance on MRN organisation identifiers.",
        "language" => "eng",
        "format" => "text/plain",
      }]
      expect(yaml("g1164-1.1")["abstract"]).to eq(expected)
      expect(yaml("g1164-1.1-e")["abstract"]).to eq(expected)
    end

    it "keeps the product-page abstract when the page has one" do
      fetcher.run
      abstract = yaml("s1070-2.0")["abstract"].first
      expect(abstract["format"]).to eq("text/html")
      expect(abstract["content"]).to include("IALA standards")
    end

    it "only adds catalogue products in the requested categories" do
      fetcher(categories: ["standards"]).run
      expect(files.grep(/\Ag1164/)).to be_empty
    end

    it "does not fetch catalogue pages whose slug is outside the requested categories" do
      fetched = []
      table = {
        "https://www.iala.int/product-category/publications/standards/" => fixture("standards.html"),
        "https://www.iala.int/product/s1070/" => fixture("product_s1070.html"),
        s1070_alias => fixture("product_s1070.html"),
      }
      backend = IalaFetcher::Http::Fake.new(
        table.merge("https://www.iala.int/product/g1164/" => ->(url) { fetched << url; fixture("product_g1164.html") }),
      )
      described_class.new(data_dir: data_dir, yaml_store: store, categories: ["standards"],
                          http_backend: backend, technical_catalogue: catalogue).run
      expect(fetched).to be_empty
    end

    it "adds the English item for a code the walk saw only in a translation category" do
      french = "https://www.iala.int/product-category/publications/recommendations-french/"
      listing = <<~HTML
        <table><tr class="post-53563 product type-product">
          <td class="highlight"><strong>G1164:fr</strong></td>
          <td><a href="https://www.iala.int/product/g1164-fr/" class="woocommerce-LoopProduct-link">G1164 FR</a></td>
          <td>17 December 2021</td></tr></table>
      HTML
      backend = IalaFetcher::Http::Fake.new(
        french => listing,
        "https://www.iala.int/product-category/publications/guidelines/" => "<html></html>",
        "https://www.iala.int/product/g1164/" => fixture("product_g1164.html"),
        "https://www.iala.int/product/g1164-fr/" => fixture("product_g1164.html"),
        s1070_alias => fixture("product_s1070.html"),
        "https://www.iala.int/product/s1070/" => fixture("product_s1070.html"),
      )
      described_class.new(
        data_dir: data_dir, yaml_store: store, categories: %w[guidelines recommendations],
        http_backend: backend, technical_catalogue: catalogue,
        language_categories: { "guidelines" => "eng", "recommendations-french" => "fra" }
      ).run
      expect(yaml("g1164-1.1")["relation"].map { |r| r["bibitem"]["docidentifier"].first["content"] })
        .to contain_exactly("IALA G1164 Ed 1.1 (E)", "IALA G1164 Ed 1.1 (F)")
    end

    it "raises when a catalogue product's code letter is missing from CATALOGUE_PREFIX_CATEGORY" do
      odd = "https://www.iala.int/product/legacy-odd-product/"
      odd_catalogue_path = File.join(tmp_dir, "odd.pdf")
      PdfBuilder.new.page(uris: [odd]).write(odd_catalogue_path)
      backend = IalaFetcher::Http::Fake.new(odd => fixture("product_g1164.html").gsub("G1164", "X1164"))
      reconciler = described_class.new(
        data_dir: data_dir, yaml_store: store, http_backend: backend,
        technical_catalogue: IalaFetcher::TechnicalCatalogue.new(odd_catalogue_path)
      )
      expect { reconciler.run_reconciliation }.to raise_error(KeyError, /"X"/)
    end

    it "gives no catalogue abstract when the catalogue lists another edition" do
      path = File.join(tmp_dir, "older.pdf")
      PdfBuilder.new.page(
        runs: [
          [57.9, 500.0, "No"], [91.9, 500.0, "Date"], [140.0, 500.0, "Title"],
          [222.3, 500.0, "Ed"], [244.9, 500.0, "Summary"],
          [57.9, 486.0, "G1164"], [91.9, 486.0, "Dec 2019"], [140.0, 486.0, "MRN OIDs"],
          [222.3, 486.0, "1.0"], [244.9, 486.0, "Summary of the old edition."],
        ],
        uris: ["https://www.iala.int/product/g1164/"],
      ).write(path)
      fetcher(technical_catalogue: IalaFetcher::TechnicalCatalogue.new(path)).run
      expect(yaml("g1164-1.1")).not_to have_key("abstract")
      expect(yaml("g1164-1.1-e")).not_to have_key("abstract")
    end

    it "does nothing extra without a catalogue" do
      fetcher(technical_catalogue: nil).run
      expect(files.grep(/\Ag1164/)).to be_empty
    end
  end

  describe "#run_reconciliation" do
    it "emits only the catalogue products that data/ does not have yet" do
      store.write("s1070-2.0", {
        "id" => "S1070-2.0",
        "docidentifier" => [{ "content" => "IALA S1070 Ed 2.0", "type" => "IALA", "primary" => true }],
        "language" => ["eng"],
        "ext" => { "flavor" => "iala", "webpage" => "https://www.iala.int/product/s1070/" },
      })
      before = File.read(store.path_for("s1070-2.0"))

      fetcher.run_reconciliation

      expect(files).to contain_exactly("s1070-2.0", "g1164-1.1", "g1164-1.1-e")
      expect(File.read(store.path_for("s1070-2.0"))).to eq(before)
    end

    it "requires a catalogue" do
      expect { fetcher(technical_catalogue: nil).run_reconciliation }
        .to raise_error(ArgumentError, /technical_catalogue/)
    end
  end
end
