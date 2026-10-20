require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "tipo y mensaje son obligatorios" do
    notification = Notification.new(recipient: users(:alumno), kind: "", message: "")

    assert_not notification.valid?
    assert notification.errors.added?(:kind, :blank)
    assert notification.errors.added?(:message, :blank)
  end
end
