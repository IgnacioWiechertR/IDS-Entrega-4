require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  def build_announcement(**attributes)
    Announcement.new({ course: courses(:one), author: users(:profesor), subject: "Aviso", body: "Contenido" }.merge(attributes))
  end

  test "toma la universidad de su asignatura" do
    announcement = build_announcement

    assert announcement.save, announcement.errors.full_messages.join(", ")
    assert_equal universities(:ucv), announcement.university
  end

  test "asunto y mensaje son obligatorios" do
    announcement = build_announcement(subject: " ", body: "")

    assert_not announcement.valid?
    assert_includes announcement.errors.full_messages, "Asunto no puede estar en blanco"
    assert_includes announcement.errors.full_messages, "Mensaje no puede estar en blanco"
  end

  test "una sección debe pertenecer a la asignatura y el autor a la universidad" do
    announcement = build_announcement(section: sections(:two), author: users(:profesor_iusa))

    assert_not announcement.valid?
    assert announcement.errors.added?(:section, :must_match_course)
    assert announcement.errors.added?(:author, :must_match_university)
  end
end
