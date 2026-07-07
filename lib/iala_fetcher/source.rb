# frozen_string_literal: true

module IalaFetcher
  # Value object that produces a relaton-compatible +source+ hash with the
  # correct +type+ for the kind of location it represents. Three
  # constructors remove the "local path tagged as website" class of bug.
  class Source
    def self.url(url)
      { "type" => "website", "content" => url }
    end

    def self.iala(path)
      return url(path) if path.start_with?("http")

      base = IalaFetcher::BASE_URL
      base = base.chomp("/")
      path = path.start_with?("/") ? path : "/#{path}"
      url("#{base}#{path}")
    end

    # The product landing page on iala.int — distinct from the PDF
    # download URL so consumers can tell "where humans read about this"
    # from "where the bytes come from". Tagged as `website` (the same
    # relaton type) but routed through a dedicated constructor so the
    # intent is explicit at the call site.
    def self.webpage(url)
      { "type" => "website", "content" => url }
    end

    def self.local(path)
      { "type" => "file", "content" => path }
    end
  end
end
