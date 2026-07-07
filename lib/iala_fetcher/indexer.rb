# frozen_string_literal: true

require "relaton/index"
require "relaton/bib"
require "relaton/iala"

module IalaFetcher
  # Builds the docid → file-path index over data/*.yaml using relaton-index.
  #
  # No type-specific logic — works uniformly for works and instances. The
  # index mirrors the data/ directory exactly on every run.
  #
  # Two index flavours, built in a single pass:
  #   * index-v1.yaml  — flat string docid → file
  #   * index-v2.yaml  — structured pubid identifier → file (when
  #     index_v2_file is given), parsed via pubid v2's IALA support
  module Indexer
    module_function

    # @param data_dir [String] directory of data/*.yaml files to index
    # @param index_file [String] path to the v1 (string) index YAML to (re)write
    # @param index_v2_file [String, nil] path to the v2 (structured pubid) index;
    #   skipped when nil
    def build(data_dir:, index_file:, index_v2_file: nil)
      idx = clean_index(file: index_file)
      pubid_class = resolve_pubid_class
      idx2 = structured_index(index_v2_file, pubid_class)
      base = File.dirname(File.expand_path(index_file))

      Dir[File.join(data_dir, "*.yaml")].sort.each do |f|
        item = Relaton::Iala::Item.from_yaml(File.read(f, encoding: "UTF-8"))
        docid = item.docidentifier.find(&:primary) || item.docidentifier.first
        unless docid
          warn "Error processing #{f}: no docidentifier"
          next
        end
        rel = File.expand_path(f).delete_prefix("#{base}/")
        idx.add_or_update docid.content, rel
        add_pubid(idx2, pubid_class, docid.content, rel) if idx2
      rescue StandardError => e
        warn "Error processing #{f}: #{e.message}"
      end

      idx.save
      idx2&.save
      [idx, idx2]
    end

    def clean_index(file:, pubid_class: nil)
      idx = Relaton::Index.find_or_create :IALA, file: file, pubid_class: pubid_class
      idx.remove_all
      idx
    end

    def structured_index(file, pubid_class)
      return nil unless file

      clean_index(file: file, pubid_class: pubid_class)
    end

    def resolve_pubid_class
      begin
        require "pubid/iala"
        Pubid::Iala::Identifier
      rescue LoadError, StandardError
        nil
      end
    end

    # A docid that pubid cannot parse must not drop the file from the v2
    # index silently breaking the v1/v2 pairing — warn and skip just the v2 entry.
    def add_pubid(idx2, pubid_class, content, rel)
      return unless pubid_class

      parsed = pubid_class.parse(content)
      idx2.add_or_update parsed, rel
    rescue StandardError => e
      warn "Skipping #{content} in index-v2: #{e.message}"
    end
  end
end
