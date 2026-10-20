# C1: tells each profesor of the section that the ayudante submitted grades for review.
class GradeSubmissionNotificationJob < ApplicationJob
  queue_as :default

  def perform(evaluation, count)
    # A job runs outside a request, so it sets the university of the evaluation itself (A3 requires one).
    ActsAsTenant.with_tenant(evaluation.university) do
      message = count == 1 ? "1 nota de #{evaluation.title_with_section} espera tu revisión." :
                             "#{count} notas de #{evaluation.title_with_section} esperan tu revisión."

      evaluation.section.section_staffs.where(role: "profesor").includes(:user).find_each do |staff|
        Notification.create!(recipient: staff.user, kind: "notas_en_revision", message: message)
      end
    end
  end
end
