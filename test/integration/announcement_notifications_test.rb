require "test_helper"

class AnnouncementNotificationsTest < ActionDispatch::IntegrationTest
  test "publicar para toda la asignatura encola el trabajo y notifica solo a inscritos activos" do
    second_section = Section.create!(course: courses(:one), term: terms(:one), number: 2)
    second_student = student(19_100_001)
    Enrollment.create!(section: second_section, student: second_student, active: true)

    inactive_student = student(19_100_002)
    Enrollment.create!(section: sections(:one), student: inactive_student, active: false)

    other_section = Section.create!(course: courses(:three), term: terms(:one), number: 1)
    other_student = student(19_100_003)
    Enrollment.create!(section: other_section, student: other_student, active: true)

    sign_in users(:profesor)
    assert_no_difference "Notification.where(kind: 'anuncio_publicado').count" do
      assert_enqueued_jobs 1, only: AnnouncementPublishedNotificationJob do
        post announcements_path, params: announcement_params(subject: "Aviso de prueba")
      end
    end
    assert_response :see_other
    announcement = Announcement.order(:id).last
    assert_enqueued_with job: AnnouncementPublishedNotificationJob,
      args: [ announcement.id, universities(:ucv).id ]

    perform_enqueued_jobs(only: AnnouncementPublishedNotificationJob)

    notifications = Notification.where(kind: "anuncio_publicado")
    assert_equal [ users(:alumno).id, second_student.id ].sort, notifications.pluck(:recipient_id).sort
    assert_equal [ "Nuevo anuncio en ICC1001: Aviso de prueba" ], notifications.distinct.pluck(:message)
    assert notifications.all? { |notification| notification.read_at.nil? && notification.university_id == universities(:ucv).id }

    sign_out :user
    sign_in users(:alumno)
    get courses_path
    assert_select "nav a[href=?][aria-label=?]", notifications_path, "Notificaciones, 1 sin leer"
    get notifications_path
    assert_select "#notifications", text: /Nuevo anuncio en ICC1001: Aviso de prueba/
    get courses_path
    assert_select "nav a[href=?][aria-label=?]", notifications_path, "Notificaciones"
  end

  test "un anuncio de sección solo notifica a inscritos activos en esa sección" do
    second_section = Section.create!(course: courses(:one), term: terms(:one), number: 2)
    another_student = student(19_100_004)
    Enrollment.create!(section: second_section, student: another_student, active: true)
    inactive_student = student(19_100_005)
    Enrollment.create!(section: sections(:one), student: inactive_student, active: false)

    sign_in users(:profesor)
    post announcements_path, params: announcement_params(section: sections(:one), subject: "Solo sección 1")
    assert_response :see_other
    perform_enqueued_jobs(only: AnnouncementPublishedNotificationJob)

    notifications = Notification.where(kind: "anuncio_publicado")
    assert_equal [ users(:alumno).id ], notifications.pluck(:recipient_id)
    assert_equal "Nuevo anuncio en ICC1001 · Sección 1: Solo sección 1", notifications.first.message
  end

  test "un anuncio de otra universidad notifica solo a sus propios alumnos" do
    sign_in users(:profesor_iusa)
    post announcements_path, params: announcement_params(course: courses(:two), section: sections(:two), subject: "Aviso IUSA")
    assert_response :see_other
    perform_enqueued_jobs(only: AnnouncementPublishedNotificationJob)

    assert_equal 0, Notification.where(kind: "anuncio_publicado").count
    ActsAsTenant.with_tenant(universities(:iusa)) do
      notifications = Notification.where(kind: "anuncio_publicado")
      assert_equal [ users(:alumno_iusa).id ], notifications.pluck(:recipient_id)
      assert_equal "Nuevo anuncio en ENF1001 · Sección 1: Aviso IUSA", notifications.first.message
    end
  end

  test "un anuncio inválido o una publicación denegada no encolan notificaciones" do
    sign_in users(:profesor)
    assert_no_enqueued_jobs only: AnnouncementPublishedNotificationJob do
      post announcements_path, params: announcement_params(subject: " ")
    end
    assert_response :unprocessable_content

    sign_out :user
    sign_in users(:alumno)
    assert_no_enqueued_jobs only: AnnouncementPublishedNotificationJob do
      post announcements_path, params: announcement_params
    end
    assert_response :redirect
    assert_equal 0, Notification.where(kind: "anuncio_publicado").count
  end

  test "un anuncio retirado antes de procesar el trabajo no genera un aviso obsoleto" do
    announcement = announcements(:one)
    AnnouncementPublishedNotificationJob.perform_later(announcement.id, universities(:ucv).id)
    announcement.destroy!

    assert_no_difference "Notification.where(kind: 'anuncio_publicado').count" do
      perform_enqueued_jobs(only: AnnouncementPublishedNotificationJob)
    end
  end

  private

  def announcement_params(course: courses(:one), section: nil, subject: "Aviso", body: "Mensaje del anuncio")
    { announcement: { course_id: course.id, section_id: section&.id, subject: subject, body: body } }
  end

  def student(number)
    User.create!(first_name: "Alumno", last_name: number.to_s, rut: Rut.build(number),
      email: "alumno#{number}@ucv.test", password: "password123", role: "alumno", university: universities(:ucv))
  end
end
