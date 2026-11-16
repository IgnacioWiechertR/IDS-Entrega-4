class MaterialFileFormat
  TEXT_EXTENSIONS = %w[txt csv tsv md].freeze
  LEGACY_OFFICE_EXTENSIONS = %w[doc xls ppt pps].freeze
  OOXML_EXTENSIONS = %w[docx xlsx pptx ppsx].freeze
  ZIP_EXTENSIONS = (OOXML_EXTENSIONS + %w[odt ods odp pages numbers key]).freeze
  EXTENSIONS = ([ "pdf", "rtf" ] + TEXT_EXTENSIONS + LEGACY_OFFICE_EXTENSIONS + ZIP_EXTENSIONS).freeze
  ACCEPT_ATTRIBUTE = EXTENSIONS.map { |extension| ".#{extension}" }.join(",").freeze

  def self.allowed?(filename, io:)
    extension = File.extname(filename).delete_prefix(".").downcase
    return false unless EXTENSIONS.include?(extension) && io.respond_to?(:read) && io.respond_to?(:rewind)

    position = io.pos
    io.rewind
    detected = Marcel::MimeType.for(io)
    expected = Marcel::MimeType.for(name: "material.#{extension}")

    if TEXT_EXTENSIONS.include?(extension)
      text_content?(io, detected)
    elsif LEGACY_OFFICE_EXTENSIONS.include?(extension)
      [ expected, "application/x-ole-storage" ].include?(detected)
    elsif ZIP_EXTENSIONS.include?(extension)
      [ expected, "application/zip" ].include?(detected) || Marcel::Magic.child?(expected, detected) ||
        (OOXML_EXTENSIONS.include?(extension) && detected == "application/x-tika-ooxml")
    elsif extension == "rtf"
      %w[application/rtf text/rtf].include?(detected)
    else
      detected == expected
    end
  ensure
    io.seek(position) if position && !io.closed?
  end

  def self.text_content?(io, detected)
    return false unless detected.start_with?("text/") || %w[application/octet-stream application/json application/xml].include?(detected)

    io.rewind
    sample = io.read(8192).to_s.b
    if sample.start_with?("\xFF\xFE".b, "\xFE\xFF".b)
      encoding = sample.start_with?("\xFF\xFE".b) ? Encoding::UTF_16LE : Encoding::UTF_16BE
      io.rewind
      content = io.read.force_encoding(encoding)
      content.valid_encoding? && !content.encode(Encoding::UTF_8).match?(/[\x00-\x08\x0B\x0C\x0E-\x1F]/)
    else
      loop do
        return false if sample.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F]/n)
        sample = io.read(8192)
        return true unless sample
        sample = sample.b
      end
    end
  end
  private_class_method :text_content?
end
