require "test_helper"

# A23: the administrativo, or the profesor who coordinates the course, assigns one or more accounts of the
# university as ayudantes of a section. An ayudante can study another course, but has one role per course.
class AssistantAssignmentsTest < ActionDispatch::IntegrationTest
  DENIED = "No tienes permiso para ver esa página.".freeze

  def in_ucv(&block) = ActsAsTenant.with_tenant(universities(:ucv), &block)

  def create_person(last_name, rut, role: "alumno")
    User.create!(first_name: "Persona", last_name: last_name, rut: rut, email: "#{last_name.downcase}@ucv.test",
      password: "password123", role: role, university: universities(:ucv))
  end

  # A section of courses(:three), where nobody teaches or studies yet.
  def free_section = in_ucv { Section.create!(course: courses(:three), term: terms(:one), number: 1) }

  # Section 2 of courses(:one): users(:alumno) studies and users(:ayudante) assists in section 1.
  def second_section_of_course_one = in_ucv { Section.create!(course: courses(:one), term: terms(:one), number: 2) }

  def assignments_path(section) = course_section_assistant_assignments_path(section.course_id, section)

  def assign(section, user_ids)
    post assignments_path(section), params: { user_ids: user_ids }
  end

  def assistants_of(section) = in_ucv { SectionStaff.where(section: section, role: "ayudante") }

  # CA1
  test "el administrativo asigna varias cuentas como ayudantes de una sección" do
    section = free_section
    people = [ create_person("Rojas", "10000001-6"), create_person("Soto", "10000002-4", role: "ayudante") ]
    sign_in users(:administrativo)

    assert_difference -> { assistants_of(section).count }, 2 do
      assign(section, people.map(&:id))
    end
    assert_redirected_to assignments_path(section)
    assert_equal "Ayudantes asignados correctamente.", flash[:notice]
    assert_equal [ users(:administrativo).id ], assistants_of(section).distinct.pluck(:assigned_by_id)
  end

  test "sin cuentas seleccionadas no asigna a nadie" do
    section = free_section
    sign_in users(:administrativo)

    assert_no_difference -> { assistants_of(section).count } do
      assign(section, [])
    end
    assert_equal "Debes seleccionar al menos una cuenta.", flash[:alert]
  end

  # CA2
  test "al asignarse, la sección aparece en Mis cursos del ayudante" do
    section = free_section
    person = create_person("Rojas", "10000001-6")
    sign_in users(:administrativo)
    assign(section, [ person.id ])

    sign_in person
    get courses_path
    assert_select "#course_#{courses(:three).id}_term_#{terms(:one).id}"
  end

  # CA3
  test "un alumno de otra asignatura puede ser ayudante" do
    section = free_section
    sign_in users(:administrativo)

    assert_difference -> { assistants_of(section).count }, 1 do
      assign(section, [ users(:alumno).id ])
    end
    assert in_ucv { Enrollment.exists?(student: users(:alumno), section: sections(:one), active: true) }
  end

  test "en la misma asignatura y período se rechaza, y no se asigna a nadie" do
    section = second_section_of_course_one
    newcomer = create_person("Nueva", "10000003-2")
    sign_in users(:administrativo)

    assert_no_difference -> { assistants_of(section).count } do
      assign(section, [ newcomer.id, users(:alumno).id ])
    end
    assert_redirected_to assignments_path(section)
    assert_match "No se asignó a nadie.", flash[:alert]
    assert_match "#{users(:alumno).name}: ya tiene un rol en este curso durante el período", flash[:alert]
  end

  test "la lista ofrece cuentas de alumno y ayudante de la universidad sin rol en la asignatura" do
    section = second_section_of_course_one
    free_student = create_person("Libre", "10000003-2")
    free_assistant = create_person("Ayuda", "10000006-7", role: "ayudante")
    sign_in users(:administrativo)

    get assignments_path(section)
    assert_response :success
    [ free_student, free_assistant ].each { |person| assert_select "#available_user_#{person.id}" }
    # Enrolled in section 1, ayudante of section 1, a profesor account, and an account of the other university.
    %i[alumno ayudante profesor alumno_iusa].each { |fixture| assert_select "#available_user_#{users(fixture).id}", count: 0 }
  end

  # CA4
  test "el profesor coordinador de la asignatura también asigna" do
    section = second_section_of_course_one
    newcomer = create_person("Nueva", "10000003-2")
    sign_in users(:profesor)

    assert_difference -> { assistants_of(section).count }, 1 do
      assign(section, [ newcomer.id ])
    end
    assert_equal users(:profesor), in_ucv { assistants_of(section).first.assigned_by }
  end

  # CA5
  test "la lista muestra quién asignó a cada ayudante y cuándo" do
    sign_in users(:administrativo)

    get assignments_path(sections(:one))
    assert_select "#assistant_#{section_staffs(:two).id}", text: /UCV, Ayudante/
    assert_select "#assistant_#{section_staffs(:two).id}",
                  text: /Asignado por #{users(:administrativo).name} el #{I18n.l(section_staffs(:two).created_at.to_date)}/
  end

  # CA6
  test "se puede quitar a un ayudante, pero no al profesor" do
    sign_in users(:administrativo)

    assert_difference -> { assistants_of(sections(:one)).count }, -1 do
      delete course_section_assistant_assignment_path(courses(:one), sections(:one), section_staffs(:two))
    end
    assert_redirected_to assignments_path(sections(:one))
    assert_equal "El ayudante fue quitado de la sección.", flash[:notice]

    assert_no_difference -> { in_ucv { SectionStaff.count } } do
      delete course_section_assistant_assignment_path(courses(:one), sections(:one), section_staffs(:one))
    end
    assert_response :not_found
  end

  test "el administrativo y el coordinador ven el botón en la sección; el ayudante no" do
    [ [ :administrativo, 1 ], [ :profesor, 1 ], [ :ayudante, 0 ] ].each do |fixture, count|
      sign_in users(fixture)
      get course_section_path(courses(:one), sections(:one))
      assert_select "a[href='#{assignments_path(sections(:one))}']", { text: "Gestionar ayudantes", count: count }, fixture.to_s
    end
  end

  # CA-AUT
  test "el director, un profesor que no coordina, el ayudante y el alumno no asignan ni quitan" do
    other_professor = create_person("Profe", "10000007-5", role: "profesor")
    section = free_section
    newcomer = create_person("Nueva", "10000003-2")

    [ users(:director), other_professor, users(:ayudante), users(:alumno) ].each do |user|
      sign_in user
      patch university_selection_path, params: { university_id: universities(:ucv).id } if user.director?

      get assignments_path(sections(:one))
      assert_equal DENIED, flash[:alert], "#{user.role} no debería ver la página"

      assert_no_difference -> { in_ucv { SectionStaff.count } } do
        assign(section, [ newcomer.id ])
        delete course_section_assistant_assignment_path(courses(:one), sections(:one), section_staffs(:two))
      end
      assert_equal DENIED, flash[:alert], "#{user.role} no debería quitar ayudantes"

      sign_out :user
    end
  end

  # CA-TEN
  test "una sección de la otra universidad responde 404" do
    sign_in users(:administrativo)
    get course_section_assistant_assignments_path(courses(:two), sections(:two))
    assert_response :not_found
  end

  test "el profesor no entra a una sección de la otra universidad aunque figure como coordinador" do
    # course_coordinators(:two) links the UCV account of the profesor with an IUSA course.
    sign_in users(:profesor)
    get course_section_assistant_assignments_path(courses(:two), sections(:two))
    assert_response :not_found
  end

  test "no se asigna una cuenta de la otra universidad" do
    section = free_section
    sign_in users(:administrativo)

    assert_no_difference -> { assistants_of(section).count } do
      assign(section, [ users(:alumno_iusa).id ])
    end
    assert_match "debe ser de la misma universidad", flash[:alert]
  end
end
