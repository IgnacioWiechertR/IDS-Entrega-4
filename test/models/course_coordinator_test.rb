require "test_helper"

class CourseCoordinatorTest < ActiveSupport::TestCase
  test "un curso tiene un solo coordinador por período" do
    duplicate = CourseCoordinator.new(course: courses(:one), term: terms(:one), user: users(:profesor), assigned_by: users(:administrativo))

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:course_id, :taken, value: courses(:one).id)
  end
end
