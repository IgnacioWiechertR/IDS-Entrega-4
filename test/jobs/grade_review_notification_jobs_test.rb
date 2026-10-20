require "test_helper"

# C5: each student is told their grade was published. C6: the ayudante is told the grades were rejected.
class GradeReviewNotificationJobsTest < ActiveJob::TestCase
  setup { ActsAsTenant.current_tenant = nil } # jobs run outside a request

  test "al publicar se avisa a cada alumno" do
    assert_difference -> { Notification.count }, 1 do
      GradesPublishedNotificationJob.perform_now(evaluations(:one), [ users(:alumno).id ])
    end

    notification = Notification.order(:id).last
    assert_equal users(:alumno), notification.recipient
    assert_equal "nota_publicada", notification.kind
    assert_equal "Tu nota de #{evaluations(:one).name} (ICC1001 · Sección 1) ya está publicada.", notification.message
  end

  test "al rechazar se avisa al ayudante, con el comentario" do
    assert_difference -> { Notification.count }, 1 do
      GradesRejectedNotificationJob.perform_now(evaluations(:one), [ users(:ayudante).id ], 3, "Revisa la pregunta 2")
    end

    notification = Notification.order(:id).last
    assert_equal users(:ayudante), notification.recipient
    assert_equal "notas_rechazadas", notification.kind
    assert_equal "El profesor rechazó 3 notas de #{evaluations(:one).name} (ICC1001 · Sección 1): «Revisa la pregunta 2»",
                 notification.message
  end
end
