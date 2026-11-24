# frozen_string_literal: true

# Writes a minimal, valid PDF for specs: one or more pages of positioned
# Helvetica text runs plus optional /URI link annotations. Lets the
# TechnicalCatalogue specs run without the 14 MB real catalogue.
#
#   PdfBuilder.new(width: 841.89, height: 595.28)
#     .page(runs: [[57.9, 430.9, "No"], ...], uris: ["https://..."])
#     .write(path)
class PdfBuilder
  Page = Struct.new(:runs, :uris, :font_size)

  def initialize(width: 841.89, height: 595.28)
    @width = width
    @height = height
    @pages = []
  end

  # @param runs [Array<Array(Float, Float, String)>] x, y, text
  # @param uris [Array<String>] link annotation targets
  def page(runs: [], uris: [], font_size: 8)
    @pages << Page.new(runs, uris, font_size)
    self
  end

  def write(path)
    File.binwrite(path, render)
    path
  end

  def render
    objects = []
    # 1: catalog, 2: pages, 3: font; then per page: page, content, annots...
    page_ids = []
    next_id = 4
    page_objects = @pages.map do |pg|
      page_id = next_id
      content_id = next_id + 1
      annot_ids = pg.uris.each_index.map { |i| next_id + 2 + i }
      next_id += 2 + pg.uris.length
      page_ids << page_id
      [pg, page_id, content_id, annot_ids]
    end

    objects[1] = "<< /Type /Catalog /Pages 2 0 R >>"
    objects[2] = "<< /Type /Pages /Kids [#{page_ids.map { |i| "#{i} 0 R" }.join(' ')}] " \
                 "/Count #{page_ids.length} >>"
    objects[3] = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica " \
                 "/Encoding /WinAnsiEncoding >>"

    page_objects.each do |pg, page_id, content_id, annot_ids|
      annots = annot_ids.empty? ? "" : " /Annots [#{annot_ids.map { |i| "#{i} 0 R" }.join(' ')}]"
      objects[page_id] = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{@width} #{@height}] " \
                         "/Resources << /Font << /F1 3 0 R >> >> /Contents #{content_id} 0 R#{annots} >>"
      stream = pg.runs.map do |x, y, text|
        "BT /F1 #{pg.font_size} Tf #{x} #{y} Td (#{escape(text)}) Tj ET"
      end.join("\n")
      objects[content_id] = "<< /Length #{stream.bytesize} >>\nstream\n#{stream}\nendstream"
      annot_ids.each_with_index do |id, i|
        objects[id] = "<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /Border [0 0 0] " \
                      "/A << /S /URI /URI (#{escape(pg.uris[i])}) >> >>"
      end
    end

    serialize(objects)
  end

  private

  def escape(text)
    text.gsub(/([()\\])/) { "\\#{Regexp.last_match(1)}" }
  end

  def serialize(objects)
    out = +"%PDF-1.4\n"
    offsets = []
    (1...objects.length).each do |id|
      offsets[id] = out.bytesize
      out << "#{id} 0 obj\n#{objects[id]}\nendobj\n"
    end
    xref_at = out.bytesize
    out << "xref\n0 #{objects.length}\n0000000000 65535 f \n"
    (1...objects.length).each { |id| out << format("%010d 00000 n \n", offsets[id]) }
    out << "trailer\n<< /Size #{objects.length} /Root 1 0 R >>\nstartxref\n#{xref_at}\n%%EOF\n"
    out
  end
end
