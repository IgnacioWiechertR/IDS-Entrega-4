class MaterialPreviewService
  class Unavailable < StandardError; end

  MAX_FILE_SIZE = 50_000_000
  TEXT_PREVIEW_SIZE = 256_000
  TEXT_EXTENSIONS = %w[txt csv tsv md].freeze
  OFFICE_EXTENSIONS = %w[doc docx rtf xls xlsx ppt pptx pps ppsx odt ods odp pages numbers key].freeze

  def initialize(attachment)
    @attachment = attachment
    @extension = File.extname(attachment.filename.to_s).delete_prefix(".").downcase if attachment.attached?
  end

  def available?
    @attachment.attached? && @attachment.byte_size.between?(1, MAX_FILE_SIZE) &&
      ([ "pdf" ] + TEXT_EXTENSIONS + OFFICE_EXTENSIONS).include?(@extension)
  end

  def text?
    TEXT_EXTENSIONS.include?(@extension)
  end

  def text
    raise Unavailable unless available? && text?

    # Read only the beginning: a 50 MB text file must not become a 50 MB HTML page.
    bytes = @attachment.blob.download_chunk(0..TEXT_PREVIEW_SIZE)
    truncated = bytes.bytesize > TEXT_PREVIEW_SIZE
    bytes = bytes.byteslice(0, TEXT_PREVIEW_SIZE)
    encoding = if bytes.start_with?("\xFF\xFE".b)
      Encoding::UTF_16LE
    elsif bytes.start_with?("\xFE\xFF".b)
      Encoding::UTF_16BE
    else
      Encoding::UTF_8
    end
    content = bytes.force_encoding(encoding).encode(Encoding::UTF_8, invalid: :replace, undef: :replace).delete_prefix("\uFEFF")
    raise Unavailable if content.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F]/)

    [ content, truncated ]
  end

  def pdf
    raise Unavailable unless available? && !text?

    @attachment.blob.open do |source|
      actual = Marcel::MimeType.for(source)
      source.rewind
      if @extension == "pdf"
        raise Unavailable unless actual == "application/pdf"
        source.read
      else
        expected = Marcel::MimeType.for(name: "material.#{@extension}")
        allowed = [ expected, "application/zip", "application/x-ole-storage", "application/x-tika-ooxml", "text/rtf" ]
        raise Unavailable unless allowed.include?(actual)
        OfficePreviewService.new.call(source.path, extension: @extension)
      end
    end
  end
end
