require "test_helper"
require_relative "../support/announcement_delivery_data"

class AnnouncementNotificationsTest < ActionDispatch::IntegrationTest
  include AnnouncementDeliveryData

  setup { setup_announcement_delivery }

  test "de punta a punta el profesor publica y el alumno abre el anuncio desde su notificación" do
    announcement = publish_and_deliver(section: @section)
    sign_out :user
    sign_in @student

    get courses_path
    assert_select "nav a[href=?]", notifications_path, text: /Notificaciones\s*1/

    get notifications_path
    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_select "#notifications a[href=?]", announcement_path(announcement), text: /Nuevo anuncio.*Próxima clase/

    get announcement_path(announcement)
    assert_response :success
    assert_select "h1", text: "Próxima clase"
    assert_select "#announcement_body", text: "Revisaremos el capítulo 2."
    assert in_ucv { Notification.find_by!(announcement: announcement, recipient: @student).read_at.present? }
  end

  test "publicar un anuncio general avisa a alumnos de las dos secciones" do
    announcement = publish_and_deliver

    assert_equal [ @student.id, @other_student.id ].sort,
      in_ucv { Notification.where(announcement: announcement).pluck(:recipient_id).sort }
  end

  test "el servidor decide los destinatarios y no acepta IDs de alumnos o universidades enviados por el formulario" do
    sign_in users(:profesor)
    perform_enqueued_jobs(only: AnnouncementPublishedNotificationJob) do
      post announcements_path, params: publication_params(section: @section).deep_merge(announcement: {
        recipient_ids: [ @other_student.id, users(:alumno_iusa).id ], university_id: universities(:iusa).id,
        author_id: users(:administrativo).id
      })
    end

    assert_response :see_other
    announcement = in_ucv { Announcement.order(:id).last }
    assert_equal users(:profesor), announcement.author
    assert_equal @university, announcement.university
    assert_equal [ @student.id ], in_ucv { Notification.where(announcement: announcement).pluck(:recipient_id) }
  end

  test "el listado está disponible antes de procesar la cola y la notificación queda encolada" do
    sign_in users(:profesor)
    assert_enqueued_jobs 1, only: AnnouncementPublishedNotificationJob do
      post announcements_path, params: publication_params(section: @section)
    end
    assert_response :see_other
    announcement = in_ucv { Announcement.order(:id).last }
    assert_equal 0, in_ucv { Notification.where(announcement: announcement).count }
    sign_out :user
    sign_in @student

    get announcements_path

    assert_response :success
    assert_select "#announcement_#{announcement.id}", count: 1
  end

  test "una publicación inválida o no autorizada no encola avisos" do
    sign_in users(:profesor)
    assert_no_enqueued_jobs only: AnnouncementPublishedNotificationJob do
      assert_no_difference "Announcement.count" do
        post announcements_path, params: publication_params.deep_merge(announcement: { body: " " })
      end
    end
    assert_response :unprocessable_content
    sign_out :user
    sign_in @student

    assert_no_enqueued_jobs only: AnnouncementPublishedNotificationJob do
      post announcements_path, params: publication_params
    end
    assert_response :redirect
  end

  test "el buzón no muestra avisos de otros destinatarios aunque se envíe su ID" do
    announcement = publish_and_deliver(section: @section)
    notification = in_ucv { Notification.find_by!(announcement: announcement, recipient: @student) }
    sign_out :user
    sign_in @other_student

    get notifications_path, params: { recipient_id: @student.id }

    assert_response :success
    assert_select "#notification_#{notification.id}", count: 0
    assert_select "a[href=?]", announcement_path(announcement), count: 0
    get announcement_path(announcement)
    assert_response :not_found
  end

  test "revocar la matrícula oculta el aviso y su contador y bloquea el enlace guardado" do
    announcement = publish_and_deliver(section: @section)
    notification = in_ucv { Notification.find_by!(announcement: announcement, recipient: @student) }
    in_ucv { Enrollment.create!(section: @unrelated_section, student: @student) }
    sign_out :user
    sign_in @student
    get courses_path
    assert_select "nav a[href=?]", notifications_path, text: /Notificaciones\s*1/
    in_ucv { @section.enrollments.find_by!(student: @student).update!(active: false) }

    get courses_path
    assert_select "nav a[href=?]", notifications_path, text: /\ANotificaciones\z/
    get notifications_path
    assert_select "#notification_#{notification.id}", count: 0
    assert_nil in_ucv { notification.reload.read_at }
    get announcement_path(announcement)
    assert_response :not_found
  end

  test "el asunto del anuncio se escapa también en el enlace de la notificación" do
    announcement = publish_and_deliver(section: @section, subject: "<script id='aviso'>alert(1)</script>")
    sign_out :user
    sign_in @student
    get notifications_path

    assert_response :success
    assert_select "a[href=?]", announcement_path(announcement), text: "Nuevo anuncio en #{@course.code}: #{announcement.subject}"
    assert_select "script#aviso", count: 0
  end

  private

  def publication_params(section: nil, subject: "Próxima clase")
    { announcement: { course_id: @course.id, section_id: section&.id, subject: subject, body: "Revisaremos el capítulo 2." } }
  end

  def publish_and_deliver(section: nil, subject: "Próxima clase")
    sign_in users(:profesor)
    perform_enqueued_jobs(only: AnnouncementPublishedNotificationJob) do
      post announcements_path, params: publication_params(section: section, subject: subject)
    end
    assert_response :see_other
    in_ucv { Announcement.order(:id).last }
  end
end
