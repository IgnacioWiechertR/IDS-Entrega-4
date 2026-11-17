require "test_helper"

class StudentAnnouncementsTest < ActionDispatch::IntegrationTest
  test "el alumno ve anuncios de su asignatura y sección pero no de otra sección o curso" do
    other_section = Section.create!(course: courses(:one), term: terms(:one), number: 2)
    course_notice = announcement_for(subject: "Para todo ICC1001")
    own_notice = announcement_for(section: sections(:one), subject: "Para sección 1")
    other_notice = announcement_for(section: other_section, subject: "Solo sección 2")
    unrelated_notice = announcement_for(course: courses(:three), subject: "Otro curso")

    sign_in users(:alumno)
    get announcements_path

    assert_response :success
    assert_select "nav a[href=?]", announcements_path, text: "Anuncios"
    assert_select "#announcement_#{course_notice.id} a[href=?]", announcement_path(course_notice)
    assert_select "#announcement_#{own_notice.id} a[href=?]", announcement_path(own_notice)
    assert_select "#announcement_#{other_notice.id}", count: 0
    assert_select "#announcement_#{unrelated_notice.id}", count: 0
    assert_select "#announcement_#{announcements(:two).id}", count: 0

    get announcement_path(own_notice)
    assert_response :success
    assert_select "h1", text: own_notice.subject
    assert_select "a[href=?]", edit_announcement_path(own_notice), count: 0
    assert_select "button", text: "Eliminar anuncio", count: 0
  end

  test "un alumno de otra sección recibe 404 incluso con el enlace directo" do
    other_section = Section.create!(course: courses(:one), term: terms(:one), number: 2)
    other_student = student(19_100_011)
    Enrollment.create!(section: other_section, student: other_student, active: true)
    course_notice = announcement_for(subject: "Para todo el curso")
    section_one_notice = announcement_for(section: sections(:one), subject: "Solo sección 1")
    section_two_notice = announcement_for(section: other_section, subject: "Solo sección 2")

    sign_in other_student
    get announcements_path
    assert_response :success
    assert_select "#announcement_#{course_notice.id}"
    assert_select "#announcement_#{section_two_notice.id}"
    assert_select "#announcement_#{section_one_notice.id}", count: 0

    get announcement_path(section_one_notice)
    assert_response :not_found

    sign_in users(:alumno)
    get announcement_path(section_two_notice)
    assert_response :not_found
    sign_in users(:alumno)
    get announcement_path(course_notice)
    assert_response :success
  end

  test "el alumno de otra universidad solo ve anuncios de sus inscripciones" do
    sign_in users(:alumno_iusa)
    get announcements_path
    assert_response :success
    assert_select "#announcement_#{announcements(:two).id}"
    assert_select "#announcement_#{announcements(:one).id}", count: 0

    get announcement_path(announcements(:one))
    assert_response :not_found
  end

  test "una inscripción inactiva no permite ver anuncios" do
    inactive_student = student(19_100_012)
    Enrollment.create!(section: sections(:one), student: inactive_student, active: false)
    sign_in inactive_student

    get announcements_path

    assert_redirected_to courses_path
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  test "el alumno inscrito ve un mensaje cuando sus secciones no tienen anuncios" do
    Announcement.delete_all
    sign_in users(:alumno)

    get announcements_path

    assert_response :success
    assert_select "#announcements_empty", text: /Aún no hay anuncios/
  end

  private

  def announcement_for(course: courses(:one), section: nil, subject:)
    Announcement.create!(course: course, section: section, author: users(:profesor),
      subject: subject, body: "Mensaje del anuncio")
  end

  def student(number)
    User.create!(first_name: "Alumna", last_name: "Sección 2", rut: Rut.build(number),
      email: "alumna#{number}@ucv.test", password: "password123", role: "alumno", university: universities(:ucv))
  end
end
