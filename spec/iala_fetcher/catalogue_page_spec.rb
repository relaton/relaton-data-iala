# frozen_string_literal: true

require "spec_helper"
require "date"

RSpec.describe IalaFetcher::CataloguePage do
  let(:standards_html) do
    File.read(File.expand_path("../fixtures/iala/standards.html", __dir__),
              encoding: "UTF-8")
  end

  let(:http_backend) { IalaFetcher::Http::Fake.new(listing_url => standards_html) }
  let(:listing_url) { "https://www.iala.int/product-category/publications/standards/" }

  let(:page) do
    described_class.new(slug: "standards", http_backend: http_backend)
  end

  it "extracts every product row" do
    rows = page.each_row.to_a
    codes = rows.map(&:code)
    expect(codes).to include("S1010", "S1020", "S1030", "S1040", "S1050", "S1060", "S1070")
  end

  it "parses the date field" do
    rows = page.each_row.to_a
    s1020 = rows.find { |r| r.code == "S1020" }
    expect(s1020.date).to eq(Date.new(2023, 6, 3))
  end

  it "captures the product URL" do
    rows = page.each_row.to_a
    s1020 = rows.find { |r| r.code == "S1020" }
    expect(s1020.product_url).to eq("https://www.iala.int/product/s1020/")
  end

  it "captures the WordPress post_id" do
    rows = page.each_row.to_a
    expect(rows.first.post_id).to be_an(Integer)
    expect(rows.first.post_id).to be > 0
  end

  it "iterates pages via #each_page" do
    pages = page.each_page.to_a
    expect(pages.length).to eq(1)
  end
end
