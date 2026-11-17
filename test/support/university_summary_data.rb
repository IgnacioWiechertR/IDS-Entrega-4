# Builds the period of a university for the dashboard tests (D1). Everything is created in the test, so the
# expected figures do not depend on the fixtures (other branches add users and data to them).
module UniversitySummaryData
  # A current term with one section and two evaluations (40 % and 60 %). The university's other terms stop
  # being current, so this one is the period of the dashboard.
  def create_summary_period(university, code)
    ActsAsTenant.with_tenant(university) do
      Term.where(current: true).update_all(current: false)
      faculty = Faculty.create!(university: university, name: "Facultad #{code}")
      course = Course.create!(university: university, faculty: faculty, code: code, name: "Asignatura #{code}")
      @summary_faculty = faculty
      @summary_course = course
      @summary_term = Term.create!(university: university, name: "Período #{code}", current: true,
        starts_on: Date.new(2026, 8, 1), ends_on: Date.new(2026, 12, 15))
      @summary_section = Section.create!(university: university, course: course, term: @summary_term, number: 1)
      @summary_teacher = summary_account("profesor", university, "profesor-#{code}")
      @summary_control = Evaluation.create!(section: @summary_section, name: "Control", weight: 40, due_on: Date.new(2026, 9, 1))
      @summary_exam = Evaluation.create!(section: @summary_section, name: "Examen", weight: 60, due_on: Date.new(2026, 11, 1))
    end
  end

  # D2: another course of the same period, in its own faculty unless one is given, with one evaluation (100 %).
  # Returns its section and its evaluation.
  def create_summary_course(university, code, faculty: nil, term: @summary_term)
    ActsAsTenant.with_tenant(university) do
      faculty ||= Faculty.create!(university: university, name: "Facultad #{code}")
      course = Course.create!(university: university, faculty: faculty, code: code, name: "Asignatura #{code}")
      section = Section.create!(university: university, course: course, term: term, number: 1)
      [ section, Evaluation.create!(section: section, name: "Examen #{code}", weight: 100, due_on: Date.new(2026, 11, 1)) ]
    end
  end

  def summary_student(university, identifier, section: @summary_section, active: true)
    student = summary_account("alumno", university, identifier)
    ActsAsTenant.with_tenant(university) { Enrollment.create!(section: section, student: student, active: active) }
    student
  end

  def summary_grade(evaluation, student, score, status: "publicada")
    ActsAsTenant.with_tenant(evaluation.university) do
      Grade.create!(evaluation: evaluation, student: student, score: score, status: status, entered_by: @summary_teacher,
        rejection_comment: (status == "rechazada" ? "Revisa" : nil))
    end
  end

  # One class of the section with the given marks ({ student => "presente" | "ausente" }).
  def summary_class(held_on, marks)
    ActsAsTenant.with_tenant(@summary_section.university) do
      session = AttendanceSession.create!(section: @summary_section, held_on: held_on, recorded_by: @summary_teacher)
      marks.each { |student, status| AttendanceRecord.create!(attendance_session: session, student: student, status: status) }
    end
  end

  def summary_account(role, university, identifier)
    @summary_user_counter = (@summary_user_counter || 0) + 1
    User.create!(first_name: "Persona", last_name: identifier, rut: Rut.build(70_000_000 + @summary_user_counter),
      email: "#{identifier}@d1.test", password: "password123", role: role, university: university)
  end
end
