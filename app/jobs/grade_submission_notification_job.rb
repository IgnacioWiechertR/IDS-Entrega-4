# C1: tells each profesor of the section that the ayudante submitted grades for review.
class GradeSubmissionNotificationJob < ApplicationJob
  queue_as :default

  def perform(evaluation, count)
    # A job runs outside a request, so it sets the university of the evaluation itself (A3 requires one).
    ActsAsTenant.with_tenant(evaluation.university) do
      section = evaluation.section
      message = "#{count} #{count == 1 ? 'nota' : 'notas'} de #{evaluation.name} " \
                "(#{section.course.code} · Sección #{section.number}) esperan tu revisión."

      section.section_staffs.where(role: "profesor").includes(:user).find_each do |staff|
        Notification.create!(recipient: staff.user, kind: "notas_en_revision", message: message)
      end
    end
  end
end
