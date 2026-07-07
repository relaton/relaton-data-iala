# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe IalaFetcher::PdfDownloader do
  let(:tmp_dir) { File.expand_path("../tmp/pdf_downloader_spec", __dir__) }
  let(:pdf_bytes) { "%PDF-1.6\nfake body\n%%EOF\n" }
  let(:url) { "https://www.iala.int/product/s1070/?download=true" }

  let(:http_backend) do
    IalaFetcher::Http::Fake.new(url => pdf_bytes)
  end

  around do |ex|
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
    ex.run
    FileUtils.rm_rf(tmp_dir)
  end

  it "downloads and caches a PDF by URL SHA1" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    path = downloader.fetch(url)
    expect(path).to eq(downloader.path_for(url))
    expect(File.binread(path)).to eq(pdf_bytes)
  end

  it "reports cached? accurately" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    expect(downloader.cached?(url)).to be false
    downloader.fetch(url)
    expect(downloader.cached?(url)).to be true
  end

  it "does not re-download when already cached" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    downloader.fetch(url)
    # Replace the fake with one that raises on any call — cached path must
    # short-circuit before the backend is touched.
    raising = IalaFetcher::Http::Fake.new({})
    allow(raising).to receive(:get) { raise "should not be called" }
    downloader2 = described_class.new(cache_dir: tmp_dir, http_backend: raising)
    expect { downloader2.fetch(url) }.not_to raise_error
  end

  it "uses a stable SHA1 of the URL for the cache filename" do
    downloader = described_class.new(cache_dir: tmp_dir, http_backend: http_backend)
    expected_hash = Digest::SHA1.hexdigest(url)
    expect(downloader.path_for(url)).to end_with("#{expected_hash}.pdf")
  end
end
