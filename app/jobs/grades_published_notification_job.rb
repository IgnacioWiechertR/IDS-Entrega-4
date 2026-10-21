# C5: tells each student that their grade of the evaluation was published.
class GradesPublishedNotificationJob < ApplicationJob
  queue_as :default

  def perform(evaluation, student_ids)
    # A job runs outside a request, so it sets the university of the evaluation itself (A3 requires one).
    ActsAsTenant.with_tenant(evaluation.university) do
      message = "Tu nota de #{evaluation.title_with_section} ya está publicada."

      User.where(id: student_ids).find_each do |student|
        Notification.create!(recipient: student, kind: "nota_publicada", message: message)
      end
    end
  end
end
