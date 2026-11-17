require "stringio"

module MaterialReadData
  def prepare_material_read_data
    @blob_keys_before_read_test = ActiveStorage::Blob.pluck(:key)
    @course = courses(:one)
    @section = sections(:one)
    @material = read_material(course: @course, title: "Guía de programación")
    @foreign_material = read_material(course: courses(:two), title: "Material de otra universidad")
  end

  def read_material(course: @course, title: "Material de prueba", filename: "guia.pdf", content: read_pdf_bytes, created_at: Time.current)
    ActsAsTenant.with_tenant(course.university) do
      # B2 also tests historical files that do not satisfy B1's current upload rules.
      Material.new(course: course, title: title, created_at: created_at,
        file: { io: StringIO.new(content), filename: filename }).tap { |material| material.save!(validate: false) }
    end
  end

  def read_pdf_bytes
    objects = [ "<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
      "<< /Length 0 >>\nstream\n\nendstream" ]
    pdf = "%PDF-1.4\n".b
    offsets = objects.each_with_index.map do |object, index|
      pdf.bytesize.tap { pdf << "#{index + 1} 0 obj\n#{object}\nendobj\n" }
    end
    startxref = pdf.bytesize
    pdf << "xref\n0 5\n0000000000 65535 f \n"
    offsets.each { |offset| pdf << format("%010d 00000 n \n", offset) }
    pdf << "trailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n#{startxref}\n%%EOF\n"
  end

  def clear_material_read_files
    ActiveStorage::Blob.where.not(key: @blob_keys_before_read_test).find_each do |blob|
      blob.service.delete(blob.key) if blob.service.is_a?(ActiveStorage::Service::DiskService)
    end
    ActsAsTenant.current_tenant = nil
  end
end
