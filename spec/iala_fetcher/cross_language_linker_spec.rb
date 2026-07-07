# frozen_string_literal: true

require "spec_helper"

RSpec.describe IalaFetcher::CrossLanguageLinker do
  Row = IalaFetcher::CataloguePage::Row

  let(:english_row) do
    Row.new(post_id: 74975, code: "R1016", title: "Mobile Marine AtoN",
            date: Date.new(2020, 12, 1), language_cell: "PDF: English",
            product_url: "https://www.iala.int/product/r1016/", category_slug: "recommendations")
  end

  let(:french_row) do
    Row.new(post_id: 74975, code: "R1016:fr", title: "Mobile Marine AtoN (FR)",
            date: Date.new(2017, 12, 15), language_cell: "PDF: French",
            product_url: "https://www.iala.int/product/r1016-aides/", category_slug: "recommendations-french")
  end

  let(:spanish_row) do
    Row.new(post_id: 74975, code: "R1016:es", title: "Mobile Marine AtoN (ES)",
            date: Date.new(2018, 1, 10), language_cell: "PDF: Spanish",
            product_url: "https://www.iala.int/product/r1016-es/", category_slug: "recommendations-spanish")
  end

  let(:english_only_row) do
    Row.new(post_id: 99_999, code: "S1070", title: "Information Services",
            date: Date.new(2023, 6, 3), language_cell: nil,
            product_url: "https://www.iala.int/product/s1070/", category_slug: "standards")
  end

  let(:codeless_row) do
    Row.new(post_id: 102_983, code: "", title: "Report on the Workshop on Radionavigation",
            date: Date.new(2026, 3, 1), language_cell: nil,
            product_url: "https://www.iala.int/product/report-on-the-workshop-on-radionavigation-and-radiocommunication-technologies/",
            category_slug: "reports-and-proceedings")
  end

  let(:resolution_row) do
    Row.new(post_id: 101_871, code: "GA01.13 (EN)", title: "Resolution on agreement with IMO, IHO and MOF",
            date: Date.new(2025, 2, 19), language_cell: "PDF: English",
            product_url: "https://www.iala.int/product/ga01-res-13-en-resolution-on-agreement-with-imo-iho-and-mof/",
            category_slug: "other-publications")
  end

  let(:linker) do
    described_class.new({
      "recommendations" => [english_row],
      "recommendations-french" => [french_row],
      "recommendations-spanish" => [spanish_row],
      "standards" => [english_only_row],
      "reports-and-proceedings" => [codeless_row],
      "other-publications" => [resolution_row],
    })
  end

  it "groups rows by post_id" do
    groups = linker.groups
    r1016 = groups.find { |g| g.post_id == 74_975 }
    expect(r1016.instances_by_language.keys).to contain_exactly("eng", "fra", "spa")
  end

  it "uses the bare English code as the work natural key for typed codes" do
    r1016 = linker.groups.find { |g| g.post_id == 74_975 }
    expect(r1016.work_natural_key).to eq("R1016")
    expect(r1016.work_doctype).to eq("recommendation")
  end

  it "yields single-instance groups for English-only items" do
    s1070 = linker.groups.find { |g| g.post_id == 99_999 }
    expect(s1070.instances_by_language.keys).to eq(["eng"])
    expect(s1070.work_natural_key).to eq("S1070")
  end

  it "falls back to URL slug for codeless items" do
    report = linker.groups.find { |g| g.post_id == 102_983 }
    expect(report.work_natural_key).to eq("report-on-the-workshop-on-radionavigation-and-radiocommunication-technologies")
    expect(report.work_doctype).to eq("report")
  end

  it "uses the resolution code (sans EN suffix) as the natural key" do
    res = linker.groups.find { |g| g.post_id == 101_871 }
    expect(res.work_natural_key).to eq("GA01.13")
    expect(res.work_doctype).to eq("resolution")
  end

  it "sorts groups by natural key" do
    keys = linker.groups.map(&:work_natural_key)
    expect(keys).to eq(keys.sort)
  end
end
