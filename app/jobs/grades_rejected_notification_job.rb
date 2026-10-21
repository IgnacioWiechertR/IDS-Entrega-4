# C6: tells the ayudante who entered the grades that the profesor rejected them, with the comment.
class GradesRejectedNotificationJob < ApplicationJob
  queue_as :default

  def perform(evaluation, assistant_ids, count, comment)
    # A job runs outside a request, so it sets the university of the evaluation itself (A3 requires one).
    ActsAsTenant.with_tenant(evaluation.university) do
      grades = count == 1 ? "1 nota" : "#{count} notas"
      message = "El profesor rechazó #{grades} de #{evaluation.title_with_section}: «#{comment}»"

      User.where(id: assistant_ids).find_each do |assistant|
        Notification.create!(recipient: assistant, kind: "notas_rechazadas", message: message)
      end
    end
  end
end
