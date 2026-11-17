require "stringio"
require "zip"

module MaterialDownloadData
  DOWNLOAD_PDF = "%PDF-1.4\nArchivo original de prueba B5\n%%EOF\n".freeze

  def prepare_material_download_data
    @download_blob_keys = ActiveStorage::Blob.pluck(:key)
    @course = courses(:one)
    @section = sections(:one)
    @material = download_material(course: @course, title: "Guía del curso")
    @foreign_material = download_material(course: courses(:two), title: "Guía de otra universidad")
  end

  def download_material(course: @course, title: "Documento del curso", filename: "guia.pdf", content: DOWNLOAD_PDF)
    ActsAsTenant.with_tenant(course.university) do
      Material.create!(course: course, title: title,
        file: { io: StringIO.new(content), filename: filename })
    end
  end

  def observe_download_storage
    events = []
    observer = ->(event) { events << event }
    ActiveSupport::Notifications.subscribed(observer, /service_(download|streaming_download|download_chunk|exist)\.active_storage/) do
      yield events
    end
    events
  end

  def download_office_document(extension)
    main_file = { "docx" => "word/document.xml", "xlsx" => "xl/workbook.xml", "pptx" => "ppt/presentation.xml" }.fetch(extension)
    Zip::OutputStream.write_buffer do |archive|
      archive.put_next_entry("[Content_Types].xml")
      archive.write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>')
      archive.put_next_entry(main_file)
      archive.write('<?xml version="1.0"?><document>Contenido original B5</document>')
    end.string
  end

  def clear_material_download_files
    ActiveStorage::Blob.where.not(key: @download_blob_keys).find_each do |blob|
      blob.service.delete(blob.key) if blob.service.is_a?(ActiveStorage::Service::DiskService)
    end
  end
end
