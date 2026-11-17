require "test_helper"

class AnnouncementNotificationTest < ActiveSupport::TestCase
  test "los avisos de notas existentes siguen siendo válidos sin anuncio" do
    notification = notifications(:one)

    assert_nil notification.announcement
    assert notification.valid?
    assert_includes Notification.visible_to(users(:alumno)), notification
    assert_not_includes Notification.visible_to(users(:alumno)), notifications(:two)
  end

  test "un aviso de anuncio requiere el registro al que enlaza" do
    notification = Notification.new(recipient: users(:alumno), kind: "anuncio_nuevo", message: "Nuevo anuncio")

    assert_not notification.valid?
    assert notification.errors.added?(:announcement, :blank)
  end

  test "no se puede asociar una notificación a un anuncio de otra universidad" do
    notification = Notification.new(recipient: users(:alumno), announcement: announcements(:two), kind: "anuncio_nuevo", message: "Ajeno")

    assert_not notification.valid?
    assert notification.errors.added?(:announcement, :must_match_university)
  end
end
