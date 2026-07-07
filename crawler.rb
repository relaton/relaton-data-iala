#!/usr/bin/env ruby
# frozen_string_literal: true

# Crawler entry point (the relaton/support workflow runs `bundle exec ruby
# crawler.rb`, then zips index*.yaml and commits).
#
# Generates index-v1 (string docid) and index-v2 (structured Pubid::Iala)
# in a single pass over data/*.yaml.

require "bundler/setup"
require "relaton/index"
require "relaton/bib"
require "iala_fetcher"

IalaFetcher::Indexer.build(
  data_dir: "data",
  index_file: "index-v1.yaml",
  index_v2_file: "index-v2.yaml",
)
