require "test_helper"

class EnrollmentTest < ActiveSupport::TestCase
  # A section of another course (or of the same course) in UCV.
  def ucv_section(code: "ICC2001", number: 1)
    course = Course.find_or_create_by!(university: universities(:ucv), code: code) do |new_course|
      new_course.faculty = faculties(:one)
      new_course.name = "Curso #{code}"
    end
    Section.create!(university: universities(:ucv), course: course, term: terms(:one), number: number)
  end

  test "un alumno no queda inscrito dos veces en la misma sección" do
    duplicate = Enrollment.new(section: sections(:one), student: users(:alumno))

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:student_id, :taken, value: users(:alumno).id)
  end

  test "se inscriben cuentas de alumno o de ayudante" do
    section = ucv_section

    assert Enrollment.new(section: section, student: users(:alumno)).valid?
    assert Enrollment.new(section: section, student: users(:ayudante)).valid?, "un ayudante puede ser alumno en otro curso"

    enrollment = Enrollment.new(section: section, student: users(:profesor))
    assert_not enrollment.valid?
    assert_includes enrollment.errors[:student], "debe ser una cuenta de alumno o ayudante"
  end

  test "el alumno es de la misma universidad que la sección" do
    enrollment = Enrollment.new(section: ucv_section, student: users(:alumno_iusa))

    assert_not enrollment.valid?
    assert_includes enrollment.errors[:student], "debe ser de la misma universidad"
  end

  test "un alumno no queda en dos secciones del mismo curso en el período" do
    enrollment = Enrollment.new(section: ucv_section(code: courses(:one).code, number: 2), student: users(:alumno))

    assert_not enrollment.valid?
    assert_includes enrollment.errors[:student], "ya tiene un rol en este curso durante el período"
  end

  test "el ayudante de un curso no se inscribe como alumno en ese curso" do
    enrollment = Enrollment.new(section: ucv_section(code: courses(:one).code, number: 2), student: users(:ayudante))

    assert_not enrollment.valid?
    assert_includes enrollment.errors[:student], "ya tiene un rol en este curso durante el período"
  end

  test "una inscripción inactiva no cuenta, así el alumno se puede cambiar de sección" do
    enrollments(:one).update!(active: false)

    assert Enrollment.new(section: ucv_section(code: courses(:one).code, number: 2), student: users(:alumno)).valid?
  end
end
