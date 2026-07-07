# frozen_string_literal: true

source "https://rubygems.org"

# Pin psych: 5.3.0 silently breaks the YAML round-trip that check_data.rb
# depends on (key ordering / quoting differences). Documented in
# relaton-data-oiml Gemfile.
gem "psych", "~> 5.2.6"

# relaton is the single combined v3 gem (the former relaton-bib /
# relaton-core / relaton-index / relaton-logger sub-gems plus all flavor
# namespaces — Oiml, Iho, Iala, etc. — were merged into it). The IALA
# flavor ships inside the gem (lib/relaton/iala/*).
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"

# pubid v2 (with IALA support) parses primary docids into structured
# identifiers for the pubid_class-based index-v2.yaml. Tracks the
# rt-new-lutaml-model branch until pubid v2 is released.
gem "pubid", git: "https://github.com/metanorma/pubid.git",
             branch: "rt-new-lutaml-model"

gem "thor",              "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false   # String#squish for translation parsing

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "webmock"
end
