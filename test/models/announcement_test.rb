require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "una sección debe pertenecer a la asignatura y el autor a la universidad" do
    announcement = Announcement.new(course: courses(:one), section: sections(:two),
      author: users(:profesor_iusa), subject: "Aviso", body: "Contenido")

    assert_not announcement.valid?
    assert announcement.errors[:section].any?
    assert announcement.errors[:author].any?
  end
end
