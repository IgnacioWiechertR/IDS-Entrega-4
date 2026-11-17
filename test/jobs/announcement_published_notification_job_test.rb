require "test_helper"
require_relative "../support/announcement_delivery_data"

class AnnouncementPublishedNotificationJobTest < ActiveJob::TestCase
  include AnnouncementDeliveryData

  setup do
    in_ucv { setup_announcement_delivery }
    ActsAsTenant.current_tenant = nil
  end

  test "notifica solo a los alumnos activos de la sección destinataria" do
    deliver(@section_announcement)

    notification = in_ucv { Notification.where(announcement: @section_announcement).sole }
    assert_equal @student, notification.recipient
    assert_equal @university, notification.university
    assert_equal "anuncio_nuevo", notification.kind
    assert_equal "Nuevo anuncio en #{@course.code}: #{@section_announcement.subject}", notification.message
    assert_nil notification.read_at
  end

  test "el anuncio general notifica a las secciones del curso sin incluir retirados otros cursos o universidades" do
    deliver(@general_announcement)

    notifications = in_ucv { Notification.where(announcement: @general_announcement).to_a }
    assert_equal [ @student.id, @other_student.id ].sort, notifications.map(&:recipient_id).sort
    assert_equal [ @university.id ], notifications.map(&:university_id).uniq
  end

  test "una persona inscrita en dos períodos del curso recibe un solo aviso general" do
    in_ucv do
      term = Term.create!(name: "Otro período B15", starts_on: Date.new(2026, 3, 1), ends_on: Date.new(2026, 7, 1))
      section = Section.create!(course: @course, term: term, number: 1)
      Enrollment.create!(section: section, student: @student)
    end

    deliver(@general_announcement)

    assert_equal 1, in_ucv { Notification.where(announcement: @general_announcement, recipient: @student).count }
    assert_equal 2, in_ucv { Notification.where(announcement: @general_announcement).count }
  end

  test "revalida las matrículas al ejecutar y no añade alumnos inscritos después de publicar" do
    snapshot = in_ucv { @general_announcement.student_recipients.ids }
    in_ucv do
      @other_section.enrollments.find_by!(student: @other_student).update!(active: false)
      @section.enrollments.find_by!(student: @inactive_student).update!(active: true)
    end

    deliver(@general_announcement, student_ids: snapshot)

    assert_equal [ @student.id ], in_ucv { Notification.where(announcement: @general_announcement).pluck(:recipient_id) }
  end

  test "los IDs ajenos no amplían los destinatarios de una sección" do
    deliver(@section_announcement, student_ids: [ @student.id, @other_student.id, @unrelated_student.id, users(:alumno_iusa).id ])

    assert_equal [ @student.id ], in_ucv { Notification.where(announcement: @section_announcement).pluck(:recipient_id) }
  end

  test "un reintento no duplica avisos ni vuelve a marcar como no leído uno que ya fue leído" do
    deliver(@section_announcement)
    notification = in_ucv { Notification.where(announcement: @section_announcement).sole }
    in_ucv { notification.update!(read_at: Time.current) }
    read_at = notification.reload.read_at

    deliver(@section_announcement)

    assert_equal [ notification.id ], in_ucv { Notification.where(announcement: @section_announcement).ids }
    assert_equal read_at, in_ucv { notification.reload.read_at }
  end

  test "la base de datos también impide duplicar el destinatario de un anuncio" do
    deliver(@section_announcement)

    in_ucv do
      assert_raises ActiveRecord::RecordNotUnique do
        Notification.transaction(requires_new: true) do
          Notification.create!(recipient: @student, announcement: @section_announcement, kind: "anuncio_nuevo", message: "Duplicado")
        end
      end
      assert_equal 1, Notification.where(announcement: @section_announcement).count
    end
  end

  test "un trabajo encolado funciona sin universidad activa y restaura el contexto" do
    assert_nil ActsAsTenant.current_tenant

    perform_enqueued_jobs do
      AnnouncementPublishedNotificationJob.perform_later(@university.id, @section_announcement.id, [ @student.id ])
    end

    assert_nil ActsAsTenant.current_tenant
    assert_equal 1, in_ucv { Notification.where(announcement: @section_announcement).count }
  end

  test "ejecuta también en IUSA y rechaza una cuenta de UCV aunque tenga el mismo RUT" do
    announcement = announcements(:two)
    AnnouncementPublishedNotificationJob.perform_now(universities(:iusa).id, announcement.id, [ users(:alumno_iusa).id, @student.id ])

    recipients = ActsAsTenant.with_tenant(universities(:iusa)) { Notification.where(announcement: announcement).pluck(:recipient_id) }
    assert_equal [ users(:alumno_iusa).id ], recipients
    assert_equal 0, in_ucv { Notification.where(kind: "anuncio_nuevo").count }
  end

  test "una universidad incorrecta no permite cargar el anuncio de otra sede" do
    AnnouncementPublishedNotificationJob.perform_now(universities(:iusa).id, @section_announcement.id, [ @student.id ])

    assert_equal 0, in_ucv { Notification.where(kind: "anuncio_nuevo").count }
    assert_nil ActsAsTenant.current_tenant
  end

  test "eliminar el anuncio retira sus avisos y un trabajo retrasado no los recrea" do
    deliver(@section_announcement)
    in_ucv { @section_announcement.destroy! }

    deliver(@section_announcement, student_ids: [ @student.id ])

    assert_equal 0, in_ucv { Notification.where(announcement_id: @section_announcement.id).count }
  end

  private

  def deliver(announcement, student_ids: nil)
    student_ids ||= in_ucv { announcement.student_recipients.ids }
    AnnouncementPublishedNotificationJob.perform_now(announcement.university_id, announcement.id, student_ids)
  end
end
