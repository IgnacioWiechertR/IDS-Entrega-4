require "test_helper"

# A24: the administrativo enrolls students of their university in a section, several at once.
class EnrollmentsTest < ActionDispatch::IntegrationTest
  def in_ucv(&block) = ActsAsTenant.with_tenant(universities(:ucv), &block)

  def create_student(last_name, rut, role: "alumno")
    User.create!(first_name: "Alumna", last_name: last_name, rut: rut, email: "#{last_name.downcase}@ucv.test",
      password: "password123", role: role, university: universities(:ucv))
  end

  # A section of courses(:three), where nobody teaches or studies yet.
  def free_section = in_ucv { Section.create!(course: courses(:three), term: terms(:one), number: 1) }

  # Section 2 of courses(:one): users(:alumno) is enrolled and users(:ayudante) assists in section 1.
  def second_section_of_course_one = in_ucv { Section.create!(course: courses(:one), term: terms(:one), number: 2) }

  def enroll(section, student_ids)
    post course_section_enrollments_path(section.course_id, section), params: { student_ids: student_ids }
  end

  test "el administrativo inscribe a varios alumnos a la vez" do
    section = free_section
    students = [ create_student("Rojas", "10000001-6"), create_student("Soto", "10000002-4") ]
    sign_in users(:administrativo)

    assert_difference -> { Enrollment.where(section: section, active: true).count }, 2 do
      enroll(section, students.map(&:id))
    end
    assert_redirected_to course_section_enrollments_path(section.course_id, section)
    assert_equal "Alumnos inscritos correctamente.", flash[:notice]
  end

  test "un ayudante también se puede inscribir como alumno en otro curso" do
    section = free_section
    sign_in users(:administrativo)

    get course_section_enrollments_path(section.course_id, section)
    assert_select "input[name='student_ids[]'][value=?]", users(:ayudante).id.to_s

    assert_difference -> { Enrollment.where(section: section).count }, 1 do
      enroll(section, [ users(:ayudante).id ])
    end
  end

  test "inscribir dos veces al mismo alumno no lo duplica" do
    sign_in users(:administrativo)

    assert_no_difference -> { Enrollment.count } do
      enroll(sections(:one), [ users(:alumno).id ])
    end
    assert_equal "Alumnos inscritos correctamente.", flash[:notice]
  end

  test "un alumno que ya está en otra sección del curso se rechaza con un mensaje, sin inscribir a nadie" do
    section = second_section_of_course_one
    newcomer = create_student("Nueva", "10000003-2")
    sign_in users(:administrativo)

    assert_no_difference -> { Enrollment.count } do
      enroll(section, [ newcomer.id, users(:alumno).id ])
    end
    assert_redirected_to course_section_enrollments_path(section.course_id, section)
    assert_match "No se inscribió a nadie", flash[:alert]
    assert_match "Alumno UCV: ya tiene un rol en este curso durante el período", flash[:alert]
  end

  test "la lista no ofrece a quienes ya tienen un rol en otra sección del curso" do
    section = second_section_of_course_one
    newcomer = create_student("Nueva", "10000003-2")
    sign_in users(:administrativo)

    get course_section_enrollments_path(section.course_id, section)
    assert_response :success
    assert_select "input[name='student_ids[]'][value=?]", newcomer.id.to_s
    assert_select "input[name='student_ids[]'][value=?]", users(:alumno).id.to_s, count: 0
    assert_select "input[name='student_ids[]'][value=?]", users(:ayudante).id.to_s, count: 0
  end

  test "sin alumnos seleccionados no se inscribe a nadie" do
    sign_in users(:administrativo)

    assert_no_difference -> { Enrollment.count } do
      enroll(sections(:one), [])
    end
    assert_equal "Debes seleccionar al menos un alumno para inscribir.", flash[:alert]
  end

  test "el profesor y el alumno no inscriben alumnos" do
    newcomer = create_student("Nueva", "10000003-2")

    %i[profesor alumno].each do |fixture|
      sign_in users(fixture)

      assert_no_difference -> { Enrollment.count } do
        enroll(sections(:one), [ newcomer.id ])
      end
      assert_equal "No tienes permiso para ver esa página.", flash[:alert], "#{fixture} no debería inscribir"

      sign_out :user
    end
  end

  test "una sección de otra universidad responde 404" do
    admin_iusa = User.create!(first_name: "Admin", last_name: "IUSA", rut: "22222222-2", email: "admin2@iusa.test",
      password: "password123", role: "administrativo", university: universities(:iusa))
    sign_in admin_iusa

    get course_section_enrollments_path(courses(:one), sections(:one))
    assert_response :not_found
  end
end
