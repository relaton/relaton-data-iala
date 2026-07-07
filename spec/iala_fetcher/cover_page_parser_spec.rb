# frozen_string_literal: true

require "spec_helper"

RSpec.describe IalaFetcher::CoverPageParser do
  let(:cover_text) do
    File.read(File.expand_path("../fixtures/iala/cover_s1070.txt", __dir__),
              encoding: "UTF-8")
  end

  it "parses the S1070 cover page" do
    result = described_class.parse(cover_text)
    expect(result.label).to eq("IALA STANDARD")
    expect(result.code).to eq("S1070")
    expect(result.title).to eq("INFORMATION SERVICES")
    expect(result.edition).to eq("2.0")
    expect(result.month_year).to eq("June 2023")
    expect(result.urn).to eq("urn:mrn:iala:pub:s1070:ed2.0")
    expect(result.doctype).to eq("standard")
  end

  it "raises on empty input" do
    expect { described_class.parse("") }.to raise_error(IalaFetcher::CoverPageParser::MissingCoverFields)
  end

  it "returns nil doctype for an unknown label" do
    result = described_class.parse("IALA NEWFANGLED\n\nX9999\nTitle\n")
    expect(result.doctype).to be_nil
  end
end
