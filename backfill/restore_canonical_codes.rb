#!/usr/bin/env ruby
# frozen_string_literal: true

# One-off: restore IALA's canonical 4-digit (and 2-digit for resolutions)
# zero-padded codes after the over-aggressive normalisation in
# normalise_codes.rb (commit b984d31). The G01 → GA01 typo fix from
# that commit IS preserved — only the leading-zero stripping is reverted.
#
# Canonical forms (per the IALA listing site, 2026-07-08):
#
#   * Typed codes (S/R/G/M/C) — 4-digit zero-padded main number:
#       M1 → M0001, R101 → R0101, C103-1 → C0103-1
#   * General Assembly resolutions (GA) — 2-digit zero-padded components:
#       GA1.1 → GA01.01, GA1.13 → GA01.13
#   * Council / legacy resolutions (A12-XX, A13-XX) — 2-digit suffix:
#       A12-1 → A12-01
#   * Legacy Level-2 codes (L2.x.x) — unchanged (already canonical)
#   * Slug-derived reports/workshops — unchanged (no numeric padding)
#
# Idempotent. Run from the repo root:
#   bundle exec ruby backfill/restore_canonical_codes.rb

require "fileutils"
require "yaml"
require "json"

REPO_ROOT = File.expand_path("..", __dir__)
DATA_DIR  = File.join(REPO_ROOT, "data")
PDFS_DIR  = File.join(REPO_ROOT, "pdfs")
MANIFEST  = File.join(PDFS_DIR, "manifest.json")

# Convert any code to its canonical zero-padded form. Typed codes get a
# 4-digit main number; resolutions get 2-digit components. Sub-parts
# and slug fragments are preserved verbatim.
def canonical_code(code)
  s = code.to_s.dup

  # Typed: S/R/G/M/C followed by digits, optionally with -subpart chain.
  # The main number zero-pads to 4 digits; sub-parts keep their form
  # (e.g. "1", "9-10") since IALA prints them unpadded.
  if (m = s.match(/\A([SRGMC])(\d+)((?:-\d+(?:-\d+)*)?)(.*)\z/i))
    letter, number, subpart, tail = m[1].upcase, m[2], m[3], m[4]
    return "#{letter}#{number.rjust(4, '0')}#{subpart}#{tail}"
  end

  # General Assembly resolutions: GA01.13, GA01.012. Each dot-separated
  # numeric component zero-pads to 2 digits.
  if s.start_with?("GA") && (rest = s[2..]) && rest.match?(/\A\d/)
    rest = rest.split(".").map { |p| p.match?(/\A\d+\z/) ? p.rjust(2, "0") : p }.join(".")
    return "GA" + rest
  end

  # Legacy A12-01 / A13-04 form: A + digits + dash + digits + optional
  # language suffix. The post-dash sequence zero-pads to 2 digits.
  if (m = s.match(/\AA(\d+)-(\d+)(.*)\z/i))
    return "A#{m[1].rjust(2, '0')}-#{m[2].rjust(2, '0')}#{m[3]}"
  end

  # Anything else (L2.x.x legacy courses, slug-derived report ids) is
  # already canonical — return unchanged.
  s
end

# Mirror IalaFetcher::Docid#filename_stem.
def filename_stem(id)
  id.downcase
   .tr(" ", "_")
   .gsub("/", "-")
   .gsub(/[^a-z0-9_.-]/, "")
   .gsub(/_+/, "_")
   .gsub(/-+/, "-")
end

def rewrite_yaml!(yaml)
  return nil unless yaml.is_a?(Hash)

  old_id = yaml["id"].to_s
  new_id = canonical_code(old_id)
  return nil if old_id == new_id

  yaml["id"] = new_id
  Array(yaml["docidentifier"]).each do |d|
    next unless d.is_a?(Hash) && d["content"]

    d["content"] = canonical_code(d["content"])
  end
  yaml["docnumber"] = canonical_code(yaml["docnumber"].to_s) if yaml["docnumber"]

  ext = yaml["ext"]
  if ext.is_a?(Hash) && ext["urn"] && ext["urn"].start_with?("urn:mrn:iala:pub:")
    body = ext["urn"].sub(/\Aurn:mrn:iala:pub:/, "")
    ext["urn"] = "urn:mrn:iala:pub:" + body.split(":").map { |seg| canonical_code(seg) }.join(":")
  end

  Array(yaml["relation"]).each do |rel|
    next unless rel.is_a?(Hash) && rel["bibitem"].is_a?(Hash)

    Array(rel["bibitem"]["docidentifier"]).each do |d|
      next unless d.is_a?(Hash) && d["content"]

      d["content"] = canonical_code(d["content"])
    end
  end

  new_id
end

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
  if seen_new_paths[new_path] && seen_new_paths[new_path] != path
    warn "  COLLISION: #{File.basename(path)} → #{File.basename(new_path)}"
    next
  end
  seen_new_paths[new_path] = path

  File.write(new_path, YAML.dump(yaml), encoding: "UTF-8")
  File.delete(path) unless path == new_path
  rename_cached_pdf(yaml["id"].to_s, new_id)
  renamed += 1
end

warn "Restored canonical form on #{renamed} YAMLs; #{skipped} unchanged."
