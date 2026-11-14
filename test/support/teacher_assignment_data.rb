module TeacherAssignmentData
  def prepare_teacher_assignment_data
    @university = University.create!(name: "Universidad A22", slug: "a22-local")
    @other_university = University.create!(name: "Otra universidad A22", slug: "a22-otra")
    @admin = create_assignment_user("administrativo", @university, "admin")
    @other_admin = create_assignment_user("administrativo", @other_university, "otro-admin")
    @professor = create_assignment_user("profesor", @university, "profesor")
    @second_professor = create_assignment_user("profesor", @university, "segundo-profesor")
    @other_professor = create_assignment_user("profesor", @other_university, "otro-profesor")
    @student = create_assignment_user("alumno", @university, "alumno")
    @assistant = create_assignment_user("ayudante", @university, "ayudante")
    @director = create_assignment_user("director", nil, "director")
    @section = create_assignment_section(@university, "LOCAL-A22")
    @other_section = create_assignment_section(@other_university, "OTRA-A22")
  end

  def create_assignment_user(role, university, identifier)
    @assignment_user_counter = (@assignment_user_counter || 0) + 1
    User.create!(
      first_name: "Persona", last_name: identifier, rut: Rut.build(90_000_000 + @assignment_user_counter),
      email: "#{identifier}@a22.test", password: "password123", role: role, university: university
    )
  end

  # University-scoped records are created inside their own university (A3).
  def create_assignment_section(university, code)
    ActsAsTenant.with_tenant(university) do
      faculty = Faculty.create!(university: university, name: "Facultad #{code}")
      course = Course.create!(university: university, faculty: faculty, code: code, name: "Asignatura #{code}")
      term = Term.create!(university: university, name: "Período #{code}",
        starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 7, 31), current: false)
      Section.create!(university: university, course: course, term: term, number: 1)
    end
  end

  def professor_assignment(**attributes)
    attributes = { section: @section, user: @professor, role: "profesor", assigned_by: @admin }.merge(attributes)
    # save!(validate: false) skips the callback that copies the section's university, so set it here.
    SectionStaff.new(university: attributes[:section].university, **attributes)
  end
end
