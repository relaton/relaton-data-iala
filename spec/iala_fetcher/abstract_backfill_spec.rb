# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require_relative "../support/pdf_builder"

RSpec.describe IalaFetcher::AbstractBackfill do
  let(:tmp_dir) { File.expand_path("../tmp/abstract_backfill_spec", __dir__) }
  let(:store) { IalaFetcher::YamlStore.new(File.join(tmp_dir, "data")) }
  let(:catalogue) do
    path = File.join(tmp_dir, "catalogue.pdf")
    PdfBuilder.new.page(runs: [
                          [57.9, 500.0, "No"], [91.9, 500.0, "Date"], [140.0, 500.0, "Title"],
                          [222.3, 500.0, "Ed"], [244.9, 500.0, "Summary"],
                          [57.9, 486.0, "G1187"], [91.9, 486.0, "Dec 2024"], [140.0, 486.0, "R-Mode"],
                          [222.3, 486.0, "1.0"], [244.9, 486.0, "Guidance on R-Mode signals."],
                        ]).write(path)
    IalaFetcher::TechnicalCatalogue.new(path)
  end

  subject(:backfill) { described_class.new(yaml_store: store, technical_catalogue: catalogue) }

  def item(id, docid, language, abstract: nil)
    hash = {
      "id" => id,
      "title" => [{ "language" => language, "content" => "Title", "type" => "main" }],
      "docidentifier" => [{ "content" => docid, "type" => "IALA", "primary" => true }],
      "language" => [language],
      "ext" => { "doctype" => { "content" => "guideline" }, "flavor" => "iala" },
    }
    hash["abstract"] = abstract if abstract
    hash
  end

  around do |ex|
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    ex.run
    FileUtils.rm_rf(tmp_dir)
  end

  it "adds the catalogue summary to English items without an abstract" do
    store.write("g1187-1.0", item("G1187-1.0", "IALA G1187 Ed 1.0", "eng"))
    store.write("g1187-1.0-e", item("G1187-1.0-E", "IALA G1187 Ed 1.0 (E)", "eng"))

    expect(backfill.run).to eq(2)

    %w[g1187-1.0 g1187-1.0-e].each do |name|
      expect(store.read(name)["abstract"]).to eq([{
        "language" => "eng", "content" => "Guidance on R-Mode signals.", "format" => "text/plain",
      }])
    end
  end

  it "leaves items with an abstract, non-English items and unknown codes alone" do
    html = [{ "content" => "<p>Page</p>", "language" => "eng", "format" => "text/html" }]
    store.write("g1187-1.0", item("G1187-1.0", "IALA G1187 Ed 1.0", "eng", abstract: html))
    store.write("g1187-1.0-f", item("G1187-1.0-F", "IALA G1187 Ed 1.0 (F)", "fra"))
    store.write("g9999-1.0", item("G9999-1.0", "IALA G9999 Ed 1.0", "eng"))
    before = Dir[File.join(tmp_dir, "data", "*.yaml")].to_h { |f| [f, File.read(f)] }

    expect(backfill.run).to eq(0)
    expect(Dir[File.join(tmp_dir, "data", "*.yaml")].to_h { |f| [f, File.read(f)] }).to eq(before)
  end

  it "is idempotent" do
    store.write("g1187-1.0", item("G1187-1.0", "IALA G1187 Ed 1.0", "eng"))
    backfill.run
    after_first = File.read(store.path_for("g1187-1.0"))

    expect(backfill.run).to eq(0)
    expect(File.read(store.path_for("g1187-1.0"))).to eq(after_first)
  end
end
