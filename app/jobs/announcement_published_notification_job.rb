# B15: notify students enrolled in the announcement's course or selected section.
class AnnouncementPublishedNotificationJob < ApplicationJob
  queue_as :default

  def perform(announcement_id, university_id)
    university = University.find_by(id: university_id)
    return unless university

    ActsAsTenant.with_tenant(university) do
      announcement = Announcement.includes(:course, :section).find_by(id: announcement_id)
      next unless announcement

      enrollments = Enrollment.where(active: true)
      enrollments = if announcement.section_id
        enrollments.where(section_id: announcement.section_id)
      else
        enrollments.joins(:section).where(sections: { course_id: announcement.course_id })
      end

      destination = announcement.section ? "#{announcement.course.code} · Sección #{announcement.section.number}" : announcement.course.code
      message = "Nuevo anuncio en #{destination}: #{announcement.subject}"

      User.where(id: enrollments.select(:student_id), university_id: university.id).find_each do |student|
        Notification.create!(recipient: student, kind: "anuncio_publicado", message: message)
      end
    end
  end
end
