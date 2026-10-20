require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "tipo y mensaje son obligatorios" do
    notification = Notification.new(recipient: users(:alumno), kind: "", message: "")

    assert_not notification.valid?
    assert notification.errors.added?(:kind, :blank)
    assert notification.errors.added?(:message, :blank)
  end

  test "las no leídas son las que no tienen read_at" do
    unread = Notification.create!(recipient: users(:alumno), kind: "prueba", message: "Nueva")
    read = Notification.create!(recipient: users(:alumno), kind: "prueba", message: "Vista", read_at: 1.hour.ago)

    assert_includes Notification.unread, unread
    assert_not_includes Notification.unread, read
  end
end
