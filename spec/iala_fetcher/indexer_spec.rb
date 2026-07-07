# frozen_string_literal: true

require "spec_helper"
require "fileutils"

RSpec.describe IalaFetcher::Indexer do
  let(:tmp_root) { File.expand_path("../tmp/indexer_spec", __dir__) }
  let(:data_dir) { File.join(tmp_root, "data") }
  let(:v1_file) { File.join(tmp_root, "index-v1.yaml") }
  let(:v2_file) { File.join(tmp_root, "index-v2.yaml") }

  def write_data(name, docid)
    path = File.join(data_dir, "#{name}.yaml")
    FileUtils.mkdir_p(data_dir)
    File.write(path, <<~YAML, encoding: "UTF-8")
      ---
      id: #{name}
      type: standard
      docidentifier:
      - content: #{docid}
        type: IALA
        primary: true
      title:
      - language: eng
        content: Test
        type: main
      ext:
        doctype:
          content: standard
        flavor: iala
    YAML
    path
  end

  around do |ex|
    FileUtils.rm_rf(tmp_root)
    FileUtils.mkdir_p(tmp_root)
    ex.run
    FileUtils.rm_rf(tmp_root)
  end

  it "builds index-v1 from data/*.yaml" do
    write_data("s1070", "IALA S1070 Ed 2.0")
    write_data("s1070-2.0-e", "IALA S1070 Ed 2.0 (E)")
    described_class.build(data_dir: data_dir, index_file: v1_file)
    contents = File.read(v1_file, encoding: "UTF-8")
    expect(contents).to include("IALA S1070 Ed 2.0")
    expect(contents).to include("IALA S1070 Ed 2.0 (E)")
  end

  it "clean-rebuilds — old entries don't linger" do
    write_data("s1070", "IALA S1070 Ed 2.0")
    described_class.build(data_dir: data_dir, index_file: v1_file)
    File.delete(File.join(data_dir, "s1070.yaml"))
    described_class.build(data_dir: data_dir, index_file: v1_file)
    contents = File.read(v1_file, encoding: "UTF-8")
    expect(contents).not_to include("IALA S1070 Ed 2.0")
  end

  it "skips files with no docidentifier from both indexes" do
    FileUtils.mkdir_p(data_dir)
    File.write(File.join(data_dir, "broken.yaml"), <<~YAML, encoding: "UTF-8")
      ---
      id: broken
      type: standard
      title:
      - language: eng
        content: No docid
        type: main
    YAML
    write_data("ok", "IALA S1070 Ed 2.0")
    described_class.build(data_dir: data_dir, index_file: v1_file)
    contents = File.read(v1_file, encoding: "UTF-8")
    expect(contents).to include("IALA S1070 Ed 2.0")
  end

  it "produces a v2 index file when pubid_class is resolvable" do
    skip "Pubid::Iala not in the bundle (rt-new-lutaml-model branch)" unless defined?(Pubid::Iala)

    write_data("s1070", "IALA S1070 Ed 2.0")
    described_class.build(data_dir: data_dir, index_file: v1_file, index_v2_file: v2_file)
    expect(File.exist?(v2_file)).to be true
  end

  it "always returns both index instances" do
    write_data("s1070", "IALA S1070 Ed 2.0")
    result = described_class.build(data_dir: data_dir, index_file: v1_file)
    expect(result).to be_an(Array)
    expect(result.length).to eq(2)
  end
end
