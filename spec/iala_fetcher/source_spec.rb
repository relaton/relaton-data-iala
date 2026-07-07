# frozen_string_literal: true

require "spec_helper"

RSpec.describe IalaFetcher::Source do
  describe ".url" do
    it "produces a website source hash" do
      expect(described_class.url("https://example.com/x.pdf"))
        .to eq({ "type" => "website", "content" => "https://example.com/x.pdf" })
    end
  end

  describe ".iala" do
    it "resolves a relative path against IALA base URL" do
      expect(described_class.iala("/product/s1070/?download=true"))
        .to eq({ "type" => "website",
                 "content" => "https://www.iala.int/product/s1070/?download=true" })
    end

    it "joins a bare relative path" do
      expect(described_class.iala("product/s1070/"))
        .to eq({ "type" => "website",
                 "content" => "https://www.iala.int/product/s1070/" })
    end

    it "passes through an absolute URL unchanged" do
      url = "https://other.example/file.pdf"
      expect(described_class.iala(url)).to eq({ "type" => "website", "content" => url })
    end
  end

  describe ".local" do
    it "produces a file source hash" do
      expect(described_class.local("pdfs/abc.pdf"))
        .to eq({ "type" => "file", "content" => "pdfs/abc.pdf" })
    end
  end
end
