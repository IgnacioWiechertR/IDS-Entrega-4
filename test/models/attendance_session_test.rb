require "test_helper"

class AttendanceSessionTest < ActiveSupport::TestCase
  def build_session(**attributes)
    AttendanceSession.new({ section: sections(:one), held_on: Date.new(2026, 10, 20), recorded_by: users(:profesor) }.merge(attributes))
  end

  test "la fecha de la clase es obligatoria" do
    session = build_session(held_on: nil)

    assert_not session.valid?
    assert session.errors.added?(:held_on, :blank)
  end

  test "hay un solo registro por sección y fecha" do
    duplicate = build_session(held_on: attendance_sessions(:one).held_on)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:held_on, :taken, value: attendance_sessions(:one).held_on)
  end
end
