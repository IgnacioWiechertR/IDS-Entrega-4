require "stringio"

module MaterialDeletionData
  DELETION_PDF = "%PDF-1.4\nArchivo de prueba B4\n%%EOF\n".freeze

  def prepare_material_deletion_data
    @deletion_blob_keys = ActiveStorage::Blob.pluck(:key)
    @course = courses(:one)
    @section = sections(:one)
    @professor = users(:profesor)
    @peer = User.create!(first_name: "Otro", last_name: "Autor", rut: Rut.build(72_123_456),
      email: "otro-autor@b4.test", role: "profesor", university: universities(:ucv), password: "password123")
    peer_section = Section.create!(course: @course, term: terms(:one), university: universities(:ucv), number: 2)
    SectionStaff.create!(section: peer_section, user: @peer, role: "profesor", assigned_by: users(:administrativo))
    @owned = deletable_material(author: @professor, title: "Material propio B4")
    @peer_material = deletable_material(author: @peer, title: "Material ajeno B4")
    @foreign = deletable_material(author: users(:profesor_iusa), course: courses(:two), title: "Material IUSA B4")
    clear_enqueued_jobs
  end

  def deletable_material(author:, course: @course, title: "Material para eliminar")
    ActsAsTenant.with_tenant(course.university) do
      Material.create!(course: course, uploaded_by: author, title: title,
        file: { io: StringIO.new(DELETION_PDF), filename: "guia-b4.pdf" })
    end
  end

  def clear_material_deletion_files
    ActiveStorage::Blob.where.not(key: @deletion_blob_keys).find_each do |blob|
      blob.service.delete(blob.key) if blob.service.is_a?(ActiveStorage::Service::DiskService)
    end
  end
end
