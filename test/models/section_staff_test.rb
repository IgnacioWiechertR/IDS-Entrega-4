require "test_helper"

class SectionStaffTest < ActiveSupport::TestCase
  def build_staff(**attributes)
    SectionStaff.new({ section: sections(:one), user: users(:profesor), role: "profesor", assigned_by: users(:administrativo) }.merge(attributes))
  end

  # A section of another course (or of the same course) in UCV.
  def ucv_section(code: "ICC2001", term: terms(:one), number: 1)
    course = Course.find_or_create_by!(university: universities(:ucv), code: code) do |new_course|
      new_course.faculty = faculties(:one)
      new_course.name = "Curso #{code}"
    end
    Section.create!(university: universities(:ucv), course: course, term: term, number: number)
  end

  def next_ucv_term
    Term.create!(university: universities(:ucv), name: "2027-1", starts_on: Date.new(2027, 3, 1), ends_on: Date.new(2027, 7, 15))
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

  test "el profesor de la sección es una cuenta de profesor" do
    staff = build_staff(section: ucv_section, user: users(:alumno))

    assert_not staff.valid?
    assert_includes staff.errors[:user], "debe ser una cuenta de profesor"
  end

  test "el ayudante es una cuenta de alumno o de ayudante" do
    section = ucv_section

    assert build_staff(section: section, user: users(:ayudante), role: "ayudante").valid?
    assert build_staff(section: section, user: users(:alumno), role: "ayudante").valid?, "un alumno puede ser ayudante de otro curso"

    %i[profesor administrativo].each do |fixture|
      staff = build_staff(section: section, user: users(fixture), role: "ayudante")
      assert_not staff.valid?, "#{fixture} no debería poder ser ayudante"
      assert_includes staff.errors[:user], "debe ser una cuenta de alumno o ayudante"
    end
  end

  test "la cuenta es de la misma universidad que la sección" do
    staff = build_staff(section: ucv_section, user: users(:alumno_iusa), role: "ayudante")

    assert_not staff.valid?
    assert_includes staff.errors[:user], "debe ser de la misma universidad"
  end

  test "un profesor no dicta dos secciones del mismo curso en el período" do
    staff = build_staff(section: ucv_section(code: courses(:one).code, number: 2))

    assert_not staff.valid?
    assert_includes staff.errors[:user], "ya tiene un rol en este curso durante el período"
  end

  test "un alumno inscrito no puede ser ayudante del mismo curso en el período" do
    staff = build_staff(section: ucv_section(code: courses(:one).code, number: 2), user: users(:alumno), role: "ayudante")

    assert_not staff.valid?
    assert_includes staff.errors[:user], "ya tiene un rol en este curso durante el período"
  end

  test "puede tener un rol en el mismo curso en otro período" do
    assert build_staff(section: ucv_section(code: courses(:one).code, term: next_ucv_term)).valid?
  end

  test "ser coordinador del curso no cuenta como rol en la sección" do
    # users(:profesor) coordinates courses(:one) in terms(:one) and teaches sections(:one).
    assert_equal users(:profesor), course_coordinators(:one).user
    assert section_staffs(:one).valid?
  end
end
