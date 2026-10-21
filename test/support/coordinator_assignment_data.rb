module CoordinatorAssignmentData
  def prepare_coordinator_assignment_data
    ActsAsTenant.without_tenant do
      @university = University.create!(name: "Universidad A15", slug: "a15-local")
      @other_university = University.create!(name: "Otra universidad A15", slug: "a15-otra")
      @admin = coordinator_account("administrativo", @university, "admin")
      @other_admin = coordinator_account("administrativo", @other_university, "otro-admin")
      @professor = coordinator_account("profesor", @university, "profesor")
      @second_professor = coordinator_account("profesor", @university, "segundo-profesor")
      @other_professor = coordinator_account("profesor", @other_university, "otro-profesor")
      @student = coordinator_account("alumno", @university, "alumno")
      @assistant = coordinator_account("ayudante", @university, "ayudante")
      @director = coordinator_account("director", nil, "director")
      @course = coordinator_course(@university, "A15-LOCAL")
      @other_course = coordinator_course(@other_university, "A15-OTRA")
      @term = coordinator_term(@university, 2026, current: true)
      @past_term = coordinator_term(@university, 2025)
      @other_term = coordinator_term(@other_university, 2026, current: true)
    end
  end

  def coordinator_account(role, university, identifier)
    @coordinator_user_counter = (@coordinator_user_counter || 0) + 1
    User.create!(first_name: "Persona", last_name: identifier,
      rut: "#{80_000_000 + @coordinator_user_counter}-0", email: "#{identifier}@a15.test",
      password: "password123", role: role, university: university)
  end

  def coordinator_course(university, code)
    faculty = Faculty.create!(university: university, name: "Facultad #{code}")
    Course.create!(university: university, faculty: faculty, code: code, name: "Asignatura #{code}")
  end

  def coordinator_term(university, year, current: false)
    Term.create!(university: university, name: "A15-#{year}", current: current,
      starts_on: Date.new(year, 3, 1), ends_on: Date.new(year, 7, 31))
  end

  def coordinator_assignment(**attributes)
    CourseCoordinator.new({ university: @university, course: @course,
      term: @term, user: @professor, assigned_by: @admin }.merge(attributes))
  end
end
