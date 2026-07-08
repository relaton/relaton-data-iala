#!/usr/bin/env ruby
# frozen_string_literal: true

# One-off: normalise IALA document codes per the user's directive
# (2026-07-08):
#
#   1. Strip leading zeros from numeric components.
#      M0001 → M1, R0101 → R101, C0103-1 → C103-1, GA01.13 → GA1.13,
#      A12-01 → A12-1.
#
#   2. Fix the G01 → GA01 typo on General Assembly resolutions.
#      Real Guidelines are G1xxx (G1001, G1015, …); G0xxx never appears
#      outside resolutions, so any code starting with G0 is a resolution
#      that should start with GA0.
#
# Walks data/*.yaml, rewrites every identifier-bearing field with the
# normalised form, writes to the new filename, removes the old. Also
# renames matching PDFs via the manifest. Idempotent.
#
# Run from the repo root:
#   bundle exec ruby backfill/normalise_codes.rb

require "fileutils"
require "yaml"
require "json"

REPO_ROOT = File.expand_path("..", __dir__)
DATA_DIR  = File.join(REPO_ROOT, "data")
PDFS_DIR  = File.join(REPO_ROOT, "pdfs")
MANIFEST  = File.join(PDFS_DIR, "manifest.json")

# Normalise a code string. Strips leading zeros from every numeric run
# and fixes the G01 → GA01 typo on resolutions. Idempotent.
def normalise_code(code)
  s = code.to_s.dup
  # G0 prefix → GA0 (General Assembly resolution typo). Real Guidelines
  # are G1xxx, so G0 unambiguously indicates a resolution.
  s = "GA" + s[1..] if s.start_with?("G0")
  # Strip leading zeros from numeric runs (preserve "0" alone)
  s.gsub(/(\d+)/) { |m| m.to_i.to_s }
end

# Mirror IalaFetcher::Docid#filename_stem so renames stay consistent
# with future scrapes.
def filename_stem(id)
  id.downcase
   .tr(" ", "_")
   .gsub("/", "-")
   .gsub(/[^a-z0-9_.-]/, "")
   .gsub(/_+/, "_")
   .gsub(/-+/, "-")
end

# Rewrite every identifier-bearing field in the YAML hash. Returns the
# new id (or nil if nothing changed).
def rewrite_yaml!(yaml)
  return nil unless yaml.is_a?(Hash)

  old_id = yaml["id"].to_s
  new_id = normalise_code(old_id)
  return nil if old_id == new_id

  yaml["id"] = new_id

  # docidentifier.content — array of hashes
  Array(yaml["docidentifier"]).each do |d|
    next unless d.is_a?(Hash) && d["content"]

    d["content"] = normalise_code(d["content"])
  end

  yaml["docnumber"] = normalise_code(yaml["docnumber"].to_s) if yaml["docnumber"]

  # ext.urn — segment-by-segment after `pub:`
  ext = yaml["ext"]
  if ext.is_a?(Hash) && ext["urn"] && ext["urn"].start_with?("urn:mrn:iala:pub:")
    body = ext["urn"].sub(/\Aurn:mrn:iala:pub:/, "")
    ext["urn"] = "urn:mrn:iala:pub:" + body.split(":").map { |seg| normalise_code(seg) }.join(":")
  end

  # relation.docidentifier.content — recurse over related docids
  Array(yaml["relation"]).each do |rel|
    next unless rel.is_a?(Hash) && rel["bibitem"].is_a?(Hash)

    Array(rel["bibitem"]["docidentifier"]).each do |d|
      next unless d.is_a?(Hash) && d["content"]

      d["content"] = normalise_code(d["content"])
    end
  end

  new_id
end

# Rename a cached PDF + its OCR entry + manifest entry to match the new id.
def rename_cached_pdf(old_id, new_id)
  return if old_id == new_id || !File.exist?(MANIFEST)

  old_name = filename_stem(old_id)
  new_name = filename_stem(new_id)
  manifest = JSON.parse(File.read(MANIFEST))

  old_pdf = File.join(PDFS_DIR, "#{old_name}.pdf")
  new_pdf = File.join(PDFS_DIR, "#{new_name}.pdf")
  if File.exist?(old_pdf)
    if File.exist?(new_pdf)
      File.delete(old_pdf)
    else
      FileUtils.mv(old_pdf, new_pdf)
    end
  end

  old_md = File.join(PDFS_DIR, "ocr-cache", "#{old_name}.md")
  new_md = File.join(PDFS_DIR, "ocr-cache", "#{new_name}.md")
  FileUtils.mv(old_md, new_md) if File.exist?(old_md) && !File.exist?(new_md)

  url = manifest["name_to_url"].delete(old_name)
  return unless url

  manifest["name_to_url"][new_name] = url
  manifest["url_to_name"][url] = new_name
  File.write(MANIFEST, JSON.pretty_generate(manifest))
end

renamed = 0
skipped = 0
seen_new_paths = {}

Dir[File.join(DATA_DIR, "*.yaml")].sort.each do |path|
  yaml = YAML.safe_load(File.read(path, encoding: "UTF-8"))
  new_id = rewrite_yaml!(yaml)
  if !new_id
    skipped += 1
    next
  end

  new_path = File.join(DATA_DIR, "#{filename_stem(new_id)}.yaml")
  # Guard against collision (two old ids normalising to the same new id).
  if seen_new_paths[new_path] && seen_new_paths[new_path] != path
    warn "  COLLISION: #{File.basename(path)} → #{File.basename(new_path)} (already written by #{seen_new_paths[new_path]})"
    next
  end
  seen_new_paths[new_path] = path

  File.write(new_path, YAML.dump(yaml), encoding: "UTF-8")
  File.delete(path) unless path == new_path
  rename_cached_pdf(yaml["id"].to_s, new_id) # yaml["id"] is already new
  renamed += 1
end

warn "Normalised #{renamed} YAMLs; #{skipped} unchanged."
