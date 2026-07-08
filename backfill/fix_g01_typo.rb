#!/usr/bin/env ruby
# frozen_string_literal: true

# One-off: fix the G01 → GA01 typo on two General Assembly resolution
# codes that appear on the IALA listing site without the leading "A".
# Real Guidelines are G1xxx (G1001, G1015, …); G0xxx never appears
# outside resolutions, so any code starting with G0 is a resolution
# that should start with GA0.
#
# Unlike normalise_codes.rb (which also stripped leading zeros and was
# reverted), this script ONLY fixes the typo — it preserves IALA's
# canonical 4-digit (and 2-digit for resolutions) zero-padded form.
#
# Affects four files: g01.012{,-e}.yaml, g01.05{,-e}.yaml.
# Idempotent.

require "fileutils"
require "yaml"
require "json"

REPO_ROOT = File.expand_path("..", __dir__)
DATA_DIR  = File.join(REPO_ROOT, "data")
PDFS_DIR  = File.join(REPO_ROOT, "pdfs")
MANIFEST  = File.join(PDFS_DIR, "manifest.json")

def fix_typo(code)
  s = code.to_s.dup
  # Strip optional "IALA " prefix to find the G0 prefix
  prefix = ""
  if s.gsub!(/\AIALA\s+/i, "")
    prefix = "IALA "
  end
  s = "GA" + s[1..] if s.start_with?("G0")
  prefix + s
end

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
  new_id = fix_typo(old_id)
  return nil if old_id == new_id

  yaml["id"] = new_id
  Array(yaml["docidentifier"]).each do |d|
    next unless d.is_a?(Hash) && d["content"]

    d["content"] = fix_typo(d["content"])
  end

  ext = yaml["ext"]
  if ext.is_a?(Hash) && ext["urn"] && ext["urn"].start_with?("urn:mrn:iala:pub:")
    body = ext["urn"].sub(/\Aurn:mrn:iala:pub:/, "")
    ext["urn"] = "urn:mrn:iala:pub:" + body.split(":").map { |seg| fix_typo(seg) }.join(":")
  end

  Array(yaml["relation"]).each do |rel|
    next unless rel.is_a?(Hash) && rel["bibitem"].is_a?(Hash)

    Array(rel["bibitem"]["docidentifier"]).each do |d|
      next unless d.is_a?(Hash) && d["content"]

      d["content"] = fix_typo(d["content"])
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

  url = manifest["name_to_url"].delete(old_name)
  return unless url

  manifest["name_to_url"][new_name] = url
  manifest["url_to_name"][url] = new_name
  File.write(MANIFEST, JSON.pretty_generate(manifest))
end

renamed = 0
Dir[File.join(DATA_DIR, "*.yaml")].sort.each do |path|
  yaml = YAML.safe_load(File.read(path, encoding: "UTF-8"))
  new_id = rewrite_yaml!(yaml)
  next unless new_id

  new_path = File.join(DATA_DIR, "#{filename_stem(new_id)}.yaml")
  File.write(new_path, YAML.dump(yaml), encoding: "UTF-8")
  File.delete(path) unless path == new_path
  rename_cached_pdf(yaml["id"].to_s, new_id)
  renamed += 1
end

warn "Fixed G01 → GA01 typo on #{renamed} YAMLs."
