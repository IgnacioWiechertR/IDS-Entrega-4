require "test_helper"
require_relative "../support/announcement_delivery_data"

class StudentAnnouncementsTest < ActionDispatch::IntegrationTest
  include AnnouncementDeliveryData

  setup { setup_announcement_delivery }

  test "el alumno encuentra en el menú los anuncios generales y los de su sección" do
    sign_in @student
    get announcements_path

    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_select "nav a[href=?]", announcements_path, text: "Anuncios"
    [ @section_announcement, @general_announcement ].each do |announcement|
      assert_select "#announcement_#{announcement.id} a[href=?]", announcement_path(announcement), text: announcement.subject
    end
    [ @other_announcement, @unrelated_announcement, announcements(:two) ].each do |announcement|
      assert_select "#announcement_#{announcement.id}", count: 0
    end

    get announcement_path(@section_announcement)

    assert_response :success
    assert_select "h1", text: @section_announcement.subject
    assert_select "#announcement_body", text: @section_announcement.body
    assert_select "a[href=?]", edit_announcement_path(@section_announcement), count: 0
  end

  test "los alumnos de distintas secciones pueden consultar el anuncio general" do
    [ @student, @other_student ].each do |student|
      sign_in student
      get announcement_path(@general_announcement)
      assert_response :success
      assert_select "h1", text: @general_announcement.subject
      sign_out :user
    end
  end

  test "un alumno no abre anuncios de otra sección ni de otro curso manipulando el enlace" do
    [ @section_announcement, @unrelated_announcement ].each do |announcement|
      sign_in @other_student
      get announcement_path(announcement), params: { section_id: @other_section.id, student_id: @student.id }
      assert_response :not_found
    end

    sign_in @other_student
    get announcements_path, params: { course_id: @course.id, section_id: @section.id, student_id: @student.id }
    assert_response :success
    assert_select "#announcement_#{@section_announcement.id}", count: 0
    assert_select "#announcement_#{@other_announcement.id}", count: 1
  end

  test "la cuenta de la otra universidad no ve anuncios ni accede por ID" do
    sign_in users(:alumno_iusa)
    get announcements_path, params: { university_id: @university.id }

    assert_response :success
    assert_select "#announcement_#{announcements(:two).id}", count: 1
    assert_select "#announcement_#{@section_announcement.id}", count: 0
    assert_select "#announcement_#{@general_announcement.id}", count: 0

    get announcement_path(@section_announcement)
    assert_response :not_found
  end

  test "una matrícula inactiva no permite consultar el anuncio" do
    sign_in @inactive_student
    get announcement_path(@section_announcement)

    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
    assert_not in_ucv { Ability.new(@inactive_student).can?(:read, @section_announcement) }
  end

  test "al retirarse de una sección pierde el acceso aunque conserve un enlace guardado" do
    Enrollment.create!(section: @unrelated_section, student: @student)
    sign_in @student
    get announcement_path(@section_announcement)
    assert_response :success

    in_ucv { @section.enrollments.find_by!(student: @student).update!(active: false) }

    get announcement_path(@section_announcement)
    assert_response :not_found
    get announcements_path
    assert_select "#announcement_#{@section_announcement.id}", count: 0
    assert_select "#announcement_#{@general_announcement.id}", count: 0
  end

  test "ser ayudante de otro curso no permite leer anuncios de las demás secciones donde estudia" do
    SectionStaff.create!(section: @unrelated_section, user: @student, role: "ayudante", assigned_by: users(:administrativo))
    sign_in @student
    get announcements_path

    assert_response :success
    assert_select "#announcement_#{@section_announcement.id}", count: 1
    assert_select "#announcement_#{@unrelated_announcement.id}", count: 1
    assert_select "#announcement_#{@other_announcement.id}", count: 0

    get announcement_path(@other_announcement)
    assert_response :not_found
  end

  test "una cuenta con rol ayudante también consulta los anuncios de la sección donde está inscrita" do
    assistant = announcement_student(35_100_004, role: "ayudante")
    Enrollment.create!(section: @section, student: assistant)
    sign_in assistant
    get announcement_path(@section_announcement)

    assert_response :success
    assert_select "#announcement_body", text: @section_announcement.body
  end

  test "el alumno no puede publicar editar ni eliminar anuncios" do
    sign_in @student
    original = @section_announcement.attributes

    assert_no_difference "Announcement.count" do
      post announcements_path, params: { announcement: { course_id: @course.id, subject: "Intruso", body: "Cambio" } }
    end
    assert_response :redirect

    patch announcement_path(@section_announcement), params: { announcement: { subject: "Intruso", body: "Cambio" } }
    assert_response :redirect

    assert_no_difference "Announcement.count" do
      delete announcement_path(@section_announcement)
    end
    assert_response :redirect
    assert_equal original, in_ucv { @section_announcement.reload.attributes }
  end

  test "los visitantes deben iniciar sesión y el texto del anuncio se escapa" do
    get announcements_path
    assert_redirected_to new_user_session_path
    get announcement_path(@section_announcement)
    assert_redirected_to new_user_session_path

    unsafe = announcement_record(section: @section, subject: "<script id='titulo'>alert(1)</script>", body: "<script id='cuerpo'>alert(1)</script>")
    sign_in @student
    get announcement_path(unsafe)

    assert_response :success
    assert_select "h1", text: unsafe.subject
    assert_select "#announcement_body", text: unsafe.body
    assert_select "script#titulo, script#cuerpo", count: 0
  end

  test "el listado vacío tiene un mensaje y conserva el orden del más reciente al más antiguo" do
    in_ucv { Announcement.where(course: @course).delete_all }
    sign_in @student
    get announcements_path
    assert_select "#announcements_empty", text: /Aún no hay anuncios/

    older, newer = in_ucv do
      first = announcement_record(subject: "Más antiguo")
      first.update_columns(created_at: 2.days.ago)
      [ first, announcement_record(subject: "Más reciente") ]
    end
    get announcements_path

    assert_operator response.body.index(newer.subject), :<, response.body.index(older.subject)
  end
end
