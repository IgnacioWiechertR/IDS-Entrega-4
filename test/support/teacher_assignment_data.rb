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

  # A22: a profesor who coordinates the course of @section in its term, plus two sections they do not
  # coordinate: the same course in another term, and another course in the same term.
  def prepare_coordinator_data
    @coordinator = create_assignment_user("profesor", @university, "coordinador")

    ActsAsTenant.with_tenant(@university) do
      course = @section.course
      term = @section.term
      CourseCoordinator.create!(course: course, term: term, user: @coordinator, assigned_by: @admin)

      other_term = Term.create!(university: @university, name: "Período siguiente A22",
        starts_on: Date.new(2026, 8, 1), ends_on: Date.new(2026, 12, 15), current: false)
      @other_term_section = Section.create!(university: @university, course: course, term: other_term, number: 1)

      other_course = Course.create!(university: @university, faculty: course.faculty, code: "OTRO-A22", name: "Otra asignatura A22")
      @other_course_section = Section.create!(university: @university, course: other_course, term: term, number: 1)
    end
  end

  # A course_coordinators row of the other university that points to the coordinator of this one, like an
  # inconsistent fixture. It must not grant anything (course_coordinators has no tenant yet).
  def create_cross_university_coordination
    ActsAsTenant.with_tenant(@other_university) do
      CourseCoordinator.new(university: @other_university, course: @other_section.course, term: @other_section.term,
        user: @coordinator, assigned_by: @other_admin).save!(validate: false)
    end
  end

  def professor_assignment(**attributes)
    attributes = { section: @section, user: @professor, role: "profesor", assigned_by: @admin }.merge(attributes)
    # save!(validate: false) skips the callback that copies the section's university, so set it here.
    SectionStaff.new(university: attributes[:section].university, **attributes)
  end
end
