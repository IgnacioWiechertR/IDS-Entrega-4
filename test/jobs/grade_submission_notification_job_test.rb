require "test_helper"

# C1: when the ayudante submits grades for review, each profesor of the section is notified.
class GradeSubmissionNotificationJobTest < ActiveJob::TestCase
  test "avisa a cada profesor de la sección, y a nadie más" do
    assert_difference -> { Notification.count }, 1 do
      GradeSubmissionNotificationJob.perform_now(evaluations(:one), 3)
    end

    notification = Notification.order(:id).last
    assert_equal users(:profesor), notification.recipient
    assert_equal "notas_en_revision", notification.kind
    assert_equal "3 notas de #{evaluations(:one).name} (ICC1001 · Sección 1) esperan tu revisión.", notification.message
    assert_equal universities(:ucv), notification.university
  end

  test "funciona fuera de una petición, sin universidad activa" do
    ActsAsTenant.current_tenant = nil

    assert_difference -> { Notification.count }, 1 do
      GradeSubmissionNotificationJob.perform_now(evaluations(:one), 1)
    end
    assert_match "1 nota de", Notification.order(:id).last.message
  end
end
