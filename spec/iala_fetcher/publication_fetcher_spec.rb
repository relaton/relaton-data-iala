# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe IalaFetcher::PublicationFetcher, "#emit_group" do
  let(:tmp_dir) { File.expand_path("../tmp/publication_fetcher_spec", __dir__) }
  let(:standards_html) do
    File.read(File.expand_path("../fixtures/iala/standards.html", __dir__), encoding: "UTF-8")
  end
  let(:product_html) do
    File.read(File.expand_path("../fixtures/iala/product_s1070.html", __dir__), encoding: "UTF-8")
  end
  let(:http_backend) do
    IalaFetcher::Http::Fake.new(
      "https://www.iala.int/product-category/publications/standards/" => standards_html,
      "https://www.iala.int/product/s1070/" => product_html,
    )
  end
  let(:store) { IalaFetcher::YamlStore.new(tmp_dir) }
  let(:fetcher) do
    described_class.new(
      data_dir: tmp_dir, yaml_store: store, categories: ["standards"],
      http_backend: http_backend
    )
  end
  let(:group) do
    IalaFetcher::CrossLanguageLinker::Group.new(
      work_natural_key: "S1070",
      work_doctype: "standard",
      instances_by_language: {
        "eng" => IalaFetcher::CataloguePage::Row.new(
          post_id: 28587, code: "S1070", title: "S1070 Information Services",
          date: Date.new(2023, 6, 3), language_cell: nil,
          product_url: "https://www.iala.int/product/s1070/",
          category_slug: "standards",
        ),
      },
      post_id: 28587,
    )
  end

  around do |ex|
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    ex.run
    FileUtils.rm_rf(tmp_dir)
  end

  it "emits a Work YAML and one Instance YAML per language" do
    fetcher.send(:emit_group, group)
    files = Dir[File.join(tmp_dir, "*.yaml")].sort.map { |f| File.basename(f) }
    expect(files).to include("s1070-2.0.yaml", "s1070-2.0-e.yaml")
  end

  it "Work carries hasInstance relations matching emitted Instances" do
    fetcher.send(:emit_group, group)
    work = YAML.safe_load(File.read(File.join(tmp_dir, "s1070-2.0.yaml"), encoding: "UTF-8"))
    relation_types = work["relation"].map { |r| r["type"] }
    expect(relation_types).to include("hasInstance")
  end

  it "Instance carries instanceOf back to the Work" do
    fetcher.send(:emit_group, group)
    instance = YAML.safe_load(File.read(File.join(tmp_dir, "s1070-2.0-e.yaml"), encoding: "UTF-8"))
    relation = instance["relation"].first
    expect(relation["type"]).to eq("instanceOf")
    expect(relation["bibitem"]["docidentifier"].first["content"]).to eq("IALA S1070 Ed 2.0")
  end

  it "captures the website-side abstract when present" do
    fetcher.send(:emit_group, group)
    work = YAML.safe_load(File.read(File.join(tmp_dir, "s1070-2.0.yaml"), encoding: "UTF-8"))
    expect(work["abstract"]).not_to be_nil
    expect(work["abstract"].first["format"]).to eq("text/html")
    expect(work["abstract"].first["language"]).to eq("eng")
    expect(work["abstract"].first["content"]).to include("IALA standards")
  end

  it "uses the cover-page title typography when --pdfs is on" do
    skip "requires PDF fixture + pdftotext; covered by manual scrape"
  end

  it "falls back to product-page title when no cover is processed" do
    fetcher.send(:emit_group, group)
    work = YAML.safe_load(File.read(File.join(tmp_dir, "s1070-2.0.yaml"), encoding: "UTF-8"))
    # Cover not processed (--pdfs off); title is the product-page h1.
    expect(work["title"].first["content"]).to eq("S1070 Information Services")
  end
end
