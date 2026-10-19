require "test_helper"

class EnrollmentTest < ActiveSupport::TestCase
  test "un alumno no queda inscrito dos veces en la misma sección" do
    duplicate = Enrollment.new(section: sections(:one), student: users(:alumno))

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:student_id, :taken, value: users(:alumno).id)
  end
end
