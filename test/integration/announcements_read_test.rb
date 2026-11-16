require "test_helper"

class AnnouncementsReadTest < ActionDispatch::IntegrationTest
  test "profesor ve anuncios de sus cursos ordenados del más reciente al más antiguo" do
    older = announcement_for(subject: "Aviso anterior", created_at: 2.days.ago)
    newer = announcement_for(subject: "Aviso reciente", section: sections(:one), created_at: 1.day.ago)
    hidden = announcement_for(course: courses(:three), subject: "Aviso ajeno")

    sign_in users(:profesor)
    get announcements_path

    assert_response :success
    assert_select "nav a[href=?]", announcements_path, text: "Anuncios"
    assert_select "#announcement_#{older.id} a[href=?]", announcement_path(older), text: older.subject
    assert_select "#announcement_#{newer.id}", text: /Sección 1/
    assert_select "#announcement_#{older.id}", text: /Toda la asignatura/
    assert_select "#announcement_#{hidden.id}", count: 0
    assert_select "#announcement_#{announcements(:two).id}", count: 0
    assert_operator response.body.index(newer.subject), :<, response.body.index(older.subject)
  end

  test "ayudante ve los anuncios de su curso y el cuerpo completo" do
    announcement = announcement_for(subject: "Lectura de la semana", body: "Primera línea\nSegunda línea")

    sign_in users(:ayudante)
    get announcements_path
    assert_response :success
    assert_select "a[href=?]", announcement_path(announcement), text: announcement.subject

    get announcement_path(announcement)
    assert_response :success
    assert_select "h1", text: announcement.subject
    assert_select "#announcement_body", text: /Primera línea.*Segunda línea/m
    assert_select "a[href=?]", edit_announcement_path(announcement), count: 0
  end

  test "un ayudante con cuenta de alumno ve los anuncios de su curso" do
    student_assistant = ActsAsTenant.with_tenant(universities(:ucv)) do
      User.create!(first_name: "Alumna", last_name: "Ayudante", rut: Rut.build(19_876_543),
        email: "alumna.ayudante@ucv.test", password: "password123", role: "alumno", university: universities(:ucv)).tap do |user|
        SectionStaff.create!(section: sections(:one), user: user, role: "ayudante", assigned_by: users(:administrativo))
      end
    end
    announcement = announcement_for(subject: "Aviso para el equipo")

    sign_in student_assistant
    get announcements_path
    assert_response :success
    assert_select "nav a[href=?]", announcements_path, text: "Anuncios"
    assert_select "a[href=?]", announcement_path(announcement), text: announcement.subject

    get announcement_path(announcement)
    assert_response :success
    assert_select "h1", text: announcement.subject
  end

  test "una cuenta de ayudante que no ayuda en ninguna sección no ve el listado" do
    idle_assistant = User.create!(first_name: "Ayudante", last_name: "Sin sección", rut: Rut.build(17_654_321),
      email: "ayudante.libre@ucv.test", password: "password123", role: "ayudante", university: universities(:ucv))

    sign_in idle_assistant
    get announcements_path

    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  test "profesor y ayudante no abren anuncios de cursos ajenos" do
    hidden = announcement_for(course: courses(:three), subject: "Solo otro curso")

    %i[profesor ayudante].each do |role|
      sign_in users(role)
      get announcement_path(hidden)
      assert_response :not_found
      sign_in users(role)
      get announcement_path(announcements(:two))
      assert_response :not_found
      sign_out :user
    end
  end

  test "otros roles no tienen acceso al listado" do
    %i[administrativo alumno director].each do |role|
      sign_in users(role)
      get announcements_path
      expected_path = { administrativo: accounts_path, alumno: courses_path, director: dashboard_path }.fetch(role)
      assert_redirected_to expected_path
      sign_out :user
    end
  end

  test "muestra un mensaje si los cursos no tienen anuncios" do
    Announcement.delete_all
    sign_in users(:ayudante)

    get announcements_path

    assert_response :success
    assert_select "#announcements_empty", text: /Aún no hay anuncios/
  end

  private

  def announcement_for(course: courses(:one), section: nil, subject:, body: "Cuerpo del anuncio", created_at: Time.current)
    Announcement.create!(course: course, section: section, author: users(:profesor),
      subject: subject, body: body, created_at: created_at)
  end
end
