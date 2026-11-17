require "stringio"
require "tempfile"

module MaterialEditData
  EDIT_PDF = "%PDF-1.4\nContenido original B3\n%%EOF\n".freeze
  REPLACEMENT_PDF = "%PDF-1.4\nContenido actualizado B3\n%%EOF\n".freeze

  def prepare_material_edit_data
    @edit_blob_keys = ActiveStorage::Blob.pluck(:key)
    @course = courses(:one)
    @section = sections(:one)
    @professor = users(:profesor)
    @peer = User.create!(first_name: "Otro", last_name: "Profesor", rut: Rut.build(71_123_456),
      email: "otro-profesor@b3.test", role: "profesor", university: universities(:ucv), password: "password123")
    peer_section = Section.create!(course: @course, term: terms(:one), university: universities(:ucv), number: 2)
    SectionStaff.create!(section: peer_section, user: @peer, role: "profesor", assigned_by: users(:administrativo))
    @owned = editable_material(author: @professor, title: "Material propio")
    @peer_material = editable_material(author: @peer, title: "Material de otro profesor")
    @foreign = editable_material(author: users(:profesor_iusa), course: courses(:two), title: "Material de otra universidad")
  end

  def editable_material(author:, course: @course, title: "Material de prueba", content: EDIT_PDF)
    ActsAsTenant.with_tenant(course.university) do
      Material.create!(course: course, uploaded_by: author, title: title,
        file: { io: StringIO.new(content), filename: "original.pdf" })
    end
  end

  def edit_upload(content: REPLACEMENT_PDF, filename: "actualizado.pdf")
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: filename)
  end

  def clear_material_edit_files
    ActiveStorage::Blob.where.not(key: @edit_blob_keys).find_each do |blob|
      blob.service.delete(blob.key) if blob.service.is_a?(ActiveStorage::Service::DiskService)
    end
  end
end
