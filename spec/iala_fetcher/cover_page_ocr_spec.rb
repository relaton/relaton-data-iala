# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "webmock/rspec"

RSpec.describe IalaFetcher::CoverPageOcr do
  let(:tmp_cache) { File.expand_path("../tmp/ocr_spec", __dir__) }
  let(:api_key) { "test-key-abc" }
  let(:ocr) { described_class.new(api_key: api_key, cache_dir: tmp_cache) }
  let(:endpoint) { "https://api.z.ai/api/paas/v4/layout_parsing" }

  around do |ex|
    FileUtils.rm_rf(tmp_cache)
    ex.run
    FileUtils.rm_rf(tmp_cache)
  end

  describe ".read_api_key" do
    around do |ex|
      prev_env = ENV.delete("Z_AI_API_KEY")
      ex.run
      ENV["Z_AI_API_KEY"] = prev_env if prev_env
    end

    it "returns ENV value when set" do
      ENV["Z_AI_API_KEY"] = "env-key"
      expect(described_class.read_api_key).to eq("env-key")
    end

    it "returns the bare key when ENV is unset but ~/.zai-api-key exists" do
      ENV.delete("Z_AI_API_KEY")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.expand_path("~/.zai-api-key")).and_return(true)
      allow(File).to receive(:read).with(File.expand_path("~/.zai-api-key")).and_return("raw-key\n")
      expect(described_class.read_api_key).to eq("raw-key")
    end
  end

  describe "#ocr_first_page" do
    let(:pdf_path) { File.join(tmp_cache, "s1070-2.0-e.pdf") }
    let(:response) do
      { "md_results" => "# Cover Page\n\nIALA STANDARD\nS1070\nInformation Services\n" }
    end
    let(:name) { "s1070-2.0-e" }

    before do
      FileUtils.mkdir_p(tmp_cache)
      File.binwrite(pdf_path, "%PDF-1.6\nfake\n%%EOF\n")
    end

    it "posts to the GLM layout_parsing endpoint and returns md_results" do
      stub = stub_request(:post, endpoint).to_return(
        status: 200, body: JSON.generate(response), headers: { "Content-Type" => "application/json" }
      )
      result = ocr.ocr_first_page(pdf_path, name: name)
      expect(result).to include("IALA STANDARD")
      expect(stub).to have_been_made.once
    end

    it "caches by name so a second call doesn't hit the network" do
      stub = stub_request(:post, endpoint).to_return(
        status: 200, body: JSON.generate(response)
      )
      ocr.ocr_first_page(pdf_path, name: name)
      ocr.ocr_first_page(pdf_path, name: name)
      expect(stub).to have_been_made.once
    end

    it "writes a human-browsable cache filename when name is given" do
      stub_request(:post, endpoint).to_return(status: 200, body: JSON.generate(response))
      ocr.ocr_first_page(pdf_path, name: name)
      expect(File.exist?(File.join(tmp_cache, "#{name}.md"))).to be true
    end

    it "retries on HTTP 429 then succeeds" do
      stub_request(:post, endpoint)
        .to_return({ status: 429, body: "" }, { status: 429, body: "" },
                   { status: 200, body: JSON.generate(response) })
      allow(ocr).to receive(:sleep).and_return(nil)
      result = ocr.ocr_first_page(pdf_path, name: name)
      expect(result).to include("IALA STANDARD")
    end

    it "raises when all retries are 429" do
      stub_request(:post, endpoint).to_return(status: 429, body: "")
      allow(ocr).to receive(:sleep).and_return(nil)
      expect { ocr.ocr_first_page(pdf_path, name: name) }.to raise_error(/GLM-OCR HTTP 429/)
    end

    it "raises when the API key is missing" do
      no_key = described_class.new(api_key: nil, cache_dir: tmp_cache)
      expect { no_key.ocr_first_page(pdf_path, name: name) }
        .to raise_error(/API key missing/)
    end
  end
end
