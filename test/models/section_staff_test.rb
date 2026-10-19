require "test_helper"

class SectionStaffTest < ActiveSupport::TestCase
  def build_staff(**attributes)
    SectionStaff.new({ section: sections(:one), user: users(:profesor), role: "profesor", assigned_by: users(:administrativo) }.merge(attributes))
  end

  test "el rol en la sección es profesor o ayudante" do
    staff = build_staff(role: "alumno")

    assert_not staff.valid?
    assert staff.errors.added?(:role, :inclusion, value: "alumno")
  end

  test "una cuenta aparece una sola vez en la misma sección" do
    duplicate = build_staff(role: "ayudante")

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:user_id, :taken, value: users(:profesor).id)
  end
end
