# frozen_string_literal: true

require "spec_helper"

RSpec.describe IalaFetcher::ProductPage do
  let(:product_html) do
    File.read(File.expand_path("../fixtures/iala/product_s1070.html", __dir__),
              encoding: "UTF-8")
  end

  let(:url) { "https://www.iala.int/product/s1070/" }
  let(:http_backend) { IalaFetcher::Http::Fake.new(url => product_html) }

  let(:page) { described_class.new(url: url, http_backend: http_backend) }

  it "extracts every detail field" do
    detail = page.fetch
    expect(detail.code).to eq("S1070")
    expect(detail.title).to eq("S1070 Information Services")
    expect(detail.edition).to eq("2.0")
    expect(detail.download_url).to eq("https://www.iala.int/product/s1070/?download=true")
  end

  it "leaves optional fields nil when absent" do
    detail = page.fetch
    expect(detail.committee).to be_nil
  end

  it "preserves the post_id" do
    expect(page.fetch.post_id).to be_an(Integer)
  end
end
