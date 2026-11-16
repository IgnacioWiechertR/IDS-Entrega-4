require "stringio"

module MaterialUploadData
  PDF_BYTES = "%PDF-1.4\nMaterial de prueba B1\n%%EOF\n".freeze

  def prepare_material_upload_data
    @initial_blob_keys = ActiveStorage::Blob.pluck(:key)
    ActsAsTenant.without_tenant do
      @university = University.create!(name: "Universidad B1", slug: "b1-local")
      @other_university = University.create!(name: "Otra universidad B1", slug: "b1-otra")
      @professor = upload_account("profesor", @university, "profesor")
      @other_professor = upload_account("profesor", @other_university, "otro-profesor")
      @unassigned_professor = upload_account("profesor", @university, "sin-asignacion")
      @coordinator = upload_account("profesor", @university, "coordinador")
      @admin = upload_account("administrativo", @university, "admin")
      @other_admin = upload_account("administrativo", @other_university, "otro-admin")
      @assistant = upload_account("ayudante", @university, "ayudante")
      @student = upload_account("alumno", @university, "alumno")
      @director = upload_account("director", nil, "director")
      @course, @section = upload_course(@university, "B1-LOCAL", @professor, @admin)
      @other_course, @other_section = upload_course(@other_university, "B1-OTRA", @other_professor, @other_admin)
      faculty = @course.faculty
      @coordinated_course = Course.create!(university: @university, faculty: faculty, code: "B1-COORD", name: "Curso coordinado")
      CourseCoordinator.create!(course: @coordinated_course, term: @section.term, user: @coordinator, assigned_by: @admin)
      SectionStaff.create!(section: @section, user: @assistant, role: "ayudante", assigned_by: @admin)
      Enrollment.create!(section: @section, student: @student, active: true)
    end
  end

  def upload_account(role, university, identifier)
    @upload_user_counter = (@upload_user_counter || 0) + 1
    User.create!(first_name: "Persona", last_name: identifier,
      rut: Rut.build(70_000_000 + @upload_user_counter), email: "#{identifier}@b1.test",
      password: "password123", role: role, university: university)
  end

  def upload_course(university, code, professor, admin)
    faculty = Faculty.create!(university: university, name: "Facultad #{code}")
    course = Course.create!(university: university, faculty: faculty, code: code, name: "Asignatura #{code}")
    term = Term.create!(university: university, name: "Período #{code}",
      starts_on: Date.new(2026, 8, 1), ends_on: Date.new(2026, 12, 15), current: true)
    section = Section.create!(university: university, course: course, term: term, number: 1)
    SectionStaff.create!(section: section, user: professor, role: "profesor", assigned_by: admin)
    [ course, section ]
  end

  def file_attributes(content: PDF_BYTES, filename: "guia.pdf", content_type: "application/pdf")
    { io: StringIO.new(content), filename: filename, content_type: content_type }
  end

  def multipart_upload(content: PDF_BYTES, filename: "guia.pdf", content_type: "application/pdf")
    Rack::Test::UploadedFile.new(StringIO.new(content), content_type, original_filename: filename)
  end

  def clear_uploaded_test_files
    ActiveStorage::Blob.where.not(key: @initial_blob_keys).find_each do |blob|
      blob.service.delete(blob.key) if blob.service.is_a?(ActiveStorage::Service::DiskService)
    end
    ActsAsTenant.current_tenant = nil
  end
end
