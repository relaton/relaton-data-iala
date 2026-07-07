# frozen_string_literal: true

require "spec_helper"

RSpec.describe IalaFetcher::Scrape do
  it "is a Thor subclass with default task :fetch" do
    expect(described_class.ancestors).to include(Thor)
    expect(described_class.default_task).to eq("fetch")
  end

  it "exposes the fetch and index tasks" do
    tasks = described_class.tasks.keys
    expect(tasks).to include("fetch")
    expect(tasks).to include("index")
  end

  it "exits on failure when given a non-existent task" do
    expect { described_class.start(["nonexistent"]) }
      .to raise_error(SystemExit)
  end

  it "accepts --type as a repeatable option" do
    options = described_class.tasks["fetch"].options
    type_option = options[:type]
    expect(type_option.type).to eq(:string)
    # Thor::Option exposes the flag via the `repeatable` reader (no `?`).
    expect(type_option.repeatable).to be true
  end

  it "defaults --data-dir to 'data'" do
    options = described_class.tasks["fetch"].options
    expect(options[:data_dir].default).to eq("data")
  end
end
