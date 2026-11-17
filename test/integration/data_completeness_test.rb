require "test_helper"

class DataCompletenessTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @records = Hash.new { |hash, key| hash[key] = {} }
    @user_number = 0
    ActsAsTenant.without_tenant do
      %i[ucv iusa].each_with_index do |key, index|
        university = University.create!(name: "Universidad D6 #{key}", slug: "d6-#{key}")
        @records[:universities][key] = university
        suffix = index.zero? ? "" : "_iusa"
        %w[administrativo profesor ayudante alumno].each do |role|
          @records[:users]["#{role}#{suffix}".to_sym] = create_user(role, university)
        end
        ActsAsTenant.with_tenant(university) do
          label = index.zero? ? :one : :two
          faculty = Faculty.create!(university: university, name: "Facultad D6")
          course = Course.create!(university: university, faculty: faculty, code: "D6-#{key}", name: "Curso D6 #{key}")
          term = Term.create!(university: university, name: "Período D6", starts_on: Date.current.beginning_of_year, ends_on: Date.current.end_of_year)
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
          evaluation = Evaluation.create!(section: section, name: "Control D6", weight: 20, due_on: Date.current)
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
      rut: Rut.build(31000000 + @user_number), email: "d6-#{@user_number}@example.test", password: "PasswordD6!123")
  end

  test "muestra las evaluaciones pendientes y enlaces solo de la universidad propia" do
    sign_in users(:administrativo)
    get reports_data_completeness_path, params: { university_id: universities(:iusa).id }
    assert_response :success
    assert_select "li", text: "Evaluaciones con notas oficiales incompletas: 1"
    assert_select "a[href=?]", course_section_path(courses(:one), sections(:one)), text: "Revisar sección"
    assert_select "a[href=?]", course_section_path(courses(:two), sections(:two)), count: 0
    assert_select "nav a[href=?]", reports_data_completeness_path
  end

  test "identifica profesor alumnos y asistencia faltantes aun con una sesion vacia" do
    SectionStaff.where(section: sections(:one), role: "profesor").delete_all
    enrollments(:one).update!(active: false)
    attendance_records(:one).destroy!
    sign_in users(:administrativo)
    get reports_data_completeness_path
    assert_response :success
    [ "Sin profesor asignado", "Sin alumnos activos", "Sin asistencia registrada" ].each do |issue|
      assert_select "li", text: issue
    end
  end

  test "omite secciones completas y no exige notas de alumnos inactivos" do
    grades(:one).update!(status: "publicada")
    Enrollment.create!(section: sections(:one), student: users(:ayudante), active: false)
    sign_in users(:administrativo)
    get reports_data_completeness_path
    assert_response :success
    assert_select "[role=status]", text: "No se encontraron secciones con datos incompletos."
  end

  test "una publicacion parcial no oculta alumnos sin nota oficial" do
    grades(:one).update!(status: "publicada")
    SectionStaff.where(section: sections(:one), user: users(:ayudante)).delete_all
    Enrollment.create!(section: sections(:one), student: users(:ayudante), active: true)
    sign_in users(:administrativo)
    get reports_data_completeness_path
    assert_select "li", text: "Evaluaciones con notas oficiales incompletas: 1"
  end

  test "detecta evaluaciones sin notas y notas rechazadas" do
    grades(:one).update!(status: "rechazada", rejection_comment: "Corregir")
    Evaluation.create!(section: sections(:one), name: "Sin notas", due_on: Date.current, weight: 10)
    sign_in users(:administrativo)
    get reports_data_completeness_path
    assert_select "li", text: "Evaluaciones con notas oficiales incompletas: 2"
  end

  test "el administrativo de la otra universidad solo ve su seccion" do
    sign_in users(:administrativo_iusa)
    get reports_data_completeness_path
    assert_response :success
    assert_select "a[href=?]", course_section_path(courses(:two), sections(:two)), text: "Revisar sección"
    assert_select "a[href=?]", course_section_path(courses(:one), sections(:one)), count: 0
  end

  test "requiere sesion y rechaza otros roles" do
    get reports_data_completeness_path
    assert_redirected_to new_user_session_path
    %i[director profesor ayudante alumno].each do |role|
      sign_in users(role)
      get reports_data_completeness_path
      assert_response :redirect
      sign_out :user
    end
  end
end
