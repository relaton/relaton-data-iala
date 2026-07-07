# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "json"

RSpec.describe IalaFetcher::PdfDownloader do
  let(:tmp_dir) { File.expand_path("../tmp/pdf_downloader_spec", __dir__) }
  let(:pdf_bytes) { "%PDF-1.6\nfake body\n%%EOF\n" }
  let(:url) { "https://www.iala.int/product/s1070/?download=true" }
  let(:name) { "s1070-2.0-e" }

  let(:http_backend) do
    IalaFetcher::Http::Fake.new(url => pdf_bytes)
  end

  around do |ex|
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    ex.run
    FileUtils.rm_rf(tmp_dir)
  end

  it "downloads and caches a PDF by caller-supplied name" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    path = downloader.fetch(url, name: name)
    expect(path).to eq(downloader.path_for(name))
    expect(File.basename(path)).to eq("s1070-2.0-e.pdf")
    expect(File.binread(path)).to eq(pdf_bytes)
  end

  it "reports cached? accurately by name" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    expect(downloader.cached?(name)).to be false
    downloader.fetch(url, name: name)
    expect(downloader.cached?(name)).to be true
  end

  it "does not re-download when already cached" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    downloader.fetch(url, name: name)
    raising = IalaFetcher::Http::Fake.new({})
    allow(raising).to receive(:get) { raise "should not be called" }
    downloader2 = described_class.new(cache_dir: tmp_dir, http_backend: raising)
    expect { downloader2.fetch(url, name: name) }.not_to raise_error
  end

  it "records url ↔ name mapping in manifest.json" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    downloader.fetch(url, name: name)
    manifest = JSON.parse(File.read(File.join(tmp_dir, "manifest.json")))
    expect(manifest["name_to_url"][name]).to eq(url)
    expect(manifest["url_to_name"][url]).to eq(name)
    expect(downloader.url_for(name)).to eq(url)
  end

  it "sanitises unsafe characters in the name" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    path = downloader.path_for("weird/name with spaces?")
    expect(path).to end_with("weird_name_with_spaces_.pdf")
  end
end
