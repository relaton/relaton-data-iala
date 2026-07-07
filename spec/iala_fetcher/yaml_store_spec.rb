# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe IalaFetcher::YamlStore do
  let(:tmp_dir) { File.expand_path("../tmp/yaml_store_spec", __dir__) }

  before do
    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(tmp_dir)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  it "round-trips a simple hash through Relaton::Bib::Item" do
    store = described_class.new(tmp_dir)
    hash = {
      "id" => "S1070-2.0",
      "type" => "standard",
      "title" => [{ "language" => "eng", "content" => "Test", "type" => "main" }],
      "docidentifier" => [{
        "content" => "IALA S1070 Ed 2.0", "type" => "IALA", "primary" => true,
      }],
      "ext" => { "flavor" => "iala", "doctype" => { "content" => "standard" } },
    }
    store.write("test", hash)
    expect(store.exist?("test")).to be true

    data = store.read("test")
    expect(data["id"]).to eq("S1070-2.0")
    expect(data["docidentifier"].first["content"]).to eq("IALA S1070 Ed 2.0")
  end

  it "#each_yaml yields filename stems" do
    store = described_class.new(tmp_dir)
    store.write_raw("first", "---\nid: FIRST\n")
    store.write_raw("second", "---\nid: SECOND\n")
    stems = store.each_yaml.map { |name, _path| name }
    expect(stems).to contain_exactly("first", "second")
  end

  it "#patch mutates safely" do
    store = described_class.new(tmp_dir)
    store.write_raw("p", "---\nid: P\nfoo: 1\n")
    store.patch("p") do |data|
      data["foo"] = 2
      data["bar"] = "new"
    end
    expect(store.read("p")["foo"]).to eq(2)
    expect(store.read("p")["bar"]).to eq("new")
  end
end
