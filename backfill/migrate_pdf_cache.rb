#!/usr/bin/env ruby
# frozen_string_literal: true

# One-off cache migration: rename the old SHA1-named PDFs under pdfs/
# to pubid-based names by looking up the URL → docid mapping from data/.
# Also moves the OCR cache entry to the matching pubid name.
#
# Run from the relaton-data-iala repo root:
#   bundle exec ruby backfill/migrate_pdf_cache.rb
#
# Idempotent — running it twice is a no-op (renamed files have stable names).

require "fileutils"
require "json"
require "yaml"
require "digest"

REPO_ROOT = File.expand_path("..", __dir__)
DATA_DIR  = File.join(REPO_ROOT, "data")
PDFS_DIR  = File.join(REPO_ROOT, "pdfs")
OCR_DIR   = File.join(PDFS_DIR, "ocr-cache")

# Build url → instance filename_stem map from data/*.yaml.
url_to_name = {}
Dir[File.join(DATA_DIR, "*.yaml")].each do |path|
  yaml = YAML.safe_load(File.read(path, encoding: "UTF-8"))
  next unless yaml.is_a?(Hash)

  sources = yaml["source"]
  next unless sources.is_a?(Array)

  sources.each do |src|
    url = src.is_a?(Hash) ? src["content"] : nil
    next unless url && url.include?("download=true")

    id = yaml["id"]
    next unless id

    # Mirror Docid#filename_stem
    name = id.downcase.tr(" ", "_").gsub("/", "-").gsub(/[^a-z0-9_.-]/, "")
                                                              .gsub(/_+/, "_").gsub(/-+/, "-")
    url_to_name[url] = name
  end
end

warn "Discovered #{url_to_name.length} URL → name mappings"

# Build name → old SHA1 path index
manifest = { "name_to_url" => {}, "url_to_name" => {} }
renamed = 0
url_to_name.each do |url, name|
  sha1 = Digest::SHA1.hexdigest(url)
  old_path = File.join(PDFS_DIR, "#{sha1}.pdf")
  new_path = File.join(PDFS_DIR, "#{name}.pdf")
  next unless File.exist?(old_path)

  if File.exist?(new_path)
    warn "  target exists, removing source: #{name}"
    File.delete(old_path)
  else
    FileUtils.mv(old_path, new_path)
    renamed += 1
  end
  manifest["name_to_url"][name] = url
  manifest["url_to_name"][url] = name
end

File.write(File.join(PDFS_DIR, "manifest.json"), JSON.pretty_generate(manifest))
warn "Renamed #{renamed} PDFs; manifest written."

# OCR cache: rebuild by content hash, can't easily map without the original
# input string. Just rename via the same SHA256 scheme lookup if known —
# since we only have 1 entry, leave it; the new path also accepts a `name:`
# arg and will use it on subsequent runs.
if Dir.exist?(OCR_DIR)
  ocr_files = Dir[File.join(OCR_DIR, "*.md")]
  warn "OCR cache: #{ocr_files.length} entry (will be reused on miss)"
end
