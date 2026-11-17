require "test_helper"

class PendingGradeNoticeTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @records = Hash.new { |hash, key| hash[key] = {} }
    @user_number = 0
    ActsAsTenant.without_tenant do
      %i[ucv iusa].each_with_index do |key, index|
        university = University.create!(name: "Universidad Aviso #{key}", slug: "aviso-#{key}")
        @records[:universities][key] = university
        suffix = index.zero? ? "" : "_iusa"
        %w[administrativo profesor ayudante alumno].each do |role|
          @records[:users]["#{role}#{suffix}".to_sym] = create_user(role, university)
        end
        ActsAsTenant.with_tenant(university) do
          label = index.zero? ? :one : :two
          faculty = Faculty.create!(university: university, name: "Facultad Aviso")
          course = Course.create!(university: university, faculty: faculty, code: "Aviso-#{key}", name: "Curso Aviso #{key}")
          term = Term.create!(university: university, name: "Período Aviso", starts_on: Date.current.beginning_of_year, ends_on: Date.current.end_of_year)
          section = Section.create!(university: university, course: course, term: term, number: 1)
          @records[:courses][label] = course
          @records[:sections][label] = section
          admin = users("administrativo#{suffix}".to_sym)
          teacher = users("profesor#{suffix}".to_sym)
          helper = users("ayudante#{suffix}".to_sym)
          student = users("alumno#{suffix}".to_sym)
          SectionStaff.create!(section: section, user: teacher, assigned_by: admin, role: "profesor")
          SectionStaff.create!(section: section, user: helper, assigned_by: admin, role: "ayudante")
          @records[:enrollments][label] = Enrollment.create!(section: section, student: student, active: true)
          evaluation = Evaluation.create!(section: section, name: "Control Aviso", weight: 20, due_on: Date.current)
          @records[:grades][label] = Grade.create!(evaluation: evaluation, student: student, entered_by: helper, score: 5.5)
          session = AttendanceSession.create!(section: section, held_on: Date.current, recorded_by: teacher)
          @records[:attendance_records][label] = AttendanceRecord.create!(attendance_session: session, student: student, status: "presente")
        end
      end
      @records[:users][:director] = create_user("director", nil)
    end
    ActsAsTenant.test_tenant = universities(:ucv)
  end

  %i[universities users courses sections enrollments grades attendance_records].each do |collection|
    define_method(collection) { |key| @records.fetch(collection).fetch(key) }
  end

  def create_user(role, university)
    @user_number += 1
    User.create!(first_name: "Demo", last_name: role, role: role, university: university,
      rut: Rut.build(31000000 + @user_number), email: "aviso-#{@user_number}@example.test", password: "PasswordAviso!123")
  end

  test "cuenta notas pendientes de la seccion y desaparece al publicarlas" do
    sign_in users(:profesor)
    get course_section_path(courses(:one), sections(:one))
    assert_response :success
    assert_select "#pending-grade-notice", text: /\(1\)/
    assert_select "#pending-grade-notice svg.text-yellow-300", count: 0
    assert_select "#pending-grade-notice.text-yellow-300 svg", count: 1

    grades(:one).update!(status: "publicada")
    get course_section_path(courses(:one), sections(:one))
    assert_select "#pending-grade-notice", count: 0
    assert_select "a[href=?]", section_evaluations_path(sections(:one)), text: "Evaluaciones"
  end

  test "no muestra rechazadas ni muestra el aviso a otros roles" do
    sign_in users(:profesor)
    grades(:one).update!(status: "rechazada", rejection_comment: "Corregir")
    get course_section_path(courses(:one), sections(:one))
    assert_select "#pending-grade-notice", count: 0
    grades(:one).update!(status: "pendiente")
    sign_out :user
    %i[ayudante alumno administrativo].each do |role|
      sign_in users(role)
      get course_section_path(courses(:one), sections(:one))
      assert_response :success
      assert_select "#pending-grade-notice", count: 0
      sign_out :user
    end
  end
end
