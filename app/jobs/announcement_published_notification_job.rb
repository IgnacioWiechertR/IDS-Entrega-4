# B15: notify the students enrolled when the professor published the announcement.
class AnnouncementPublishedNotificationJob < ApplicationJob
  queue_as :default

  def perform(university_id, announcement_id, student_ids)
    university = University.find_by(id: university_id)
    return unless university

    ActsAsTenant.with_tenant(university) do
      announcement = Announcement.find_by(id: announcement_id)
      return unless announcement

      # Recheck enrollment before delivery: a queued job must not notify withdrawn or transferred students.
      announcement.student_recipients.where(id: student_ids).find_each do |student|
        Notification.find_or_create_by!(recipient: student, announcement: announcement) do |notification|
          notification.kind = "anuncio_nuevo"
          notification.message = "Nuevo anuncio en #{announcement.course.code}: #{announcement.subject}"
        end
      end
    end
  end
end
