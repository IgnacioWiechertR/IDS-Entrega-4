require "test_helper"
require_relative "../support/teacher_assignment_data"

class TeacherAssignmentsTest < ActionDispatch::IntegrationTest
  include TeacherAssignmentData

  setup { prepare_teacher_assignment_data }

  test "exige iniciar sesión para consultar y asignar" do
    get teacher_assignments_path
    assert_redirected_to new_user_session_path

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params
    end
    assert_redirected_to new_user_session_path
  end

  test "solo muestra secciones y profesores de la universidad del administrativo" do
    sign_in @admin
    get teacher_assignments_path

    assert_response :success
    assert_select "h1", "Asignar profesor a sección"
    assert_select "nav a[href=?]", teacher_assignments_path, text: "Asignar profesores"
    assert_select "tr#section_#{@section.id}", count: 1
    assert_select "tr#section_#{@other_section.id}", count: 0
    assert_select "option[value='#{@professor.id}']", text: @professor.name
    assert_select "option[value='#{@other_professor.id}']", count: 0
    assert_select "option[value='#{@student.id}']", count: 0
  end

  test "guarda la asignación y la muestra después de recargar" do
    sign_in @admin

    assert_difference "SectionStaff.count", 1 do
      post teacher_assignments_path, params: assignment_params
    end

    assert_response :see_other
    assert_redirected_to teacher_assignments_path
    assignment = SectionStaff.find_by!(section: @section, role: "profesor")
    assert_equal @professor, assignment.user
    assert_equal @admin, assignment.assigned_by

    follow_redirect!
    assert_select "tr#section_#{@section.id}", text: /#{Regexp.escape(@professor.name)}/
    assert_select "tr#section_#{@section.id} form", count: 0
  end

  test "el acceso aparece en el menú del administrativo pero no en otros roles" do
    sign_in @admin
    get accounts_path
    assert_response :success
    assert_select "nav a[href=?]", teacher_assignments_path, count: 1
    sign_out :user

    sign_in @director
    get dashboard_path
    assert_response :success
    assert_select "nav a[href=?]", teacher_assignments_path, count: 0
  end

  test "ignora un rol o autor enviados por el cliente" do
    sign_in @admin
    params = assignment_params
    params[:teacher_assignment].merge!(role: "ayudante", assigned_by_id: @other_admin.id)

    post teacher_assignments_path, params: params

    assert_redirected_to teacher_assignments_path
    assignment = SectionStaff.find_by!(section: @section)
    assert_equal "profesor", assignment.role
    assert_equal @admin, assignment.assigned_by
  end

  test "rechaza una sección de otra universidad aunque se envíe su ID" do
    sign_in @admin

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(section: @other_section)
    end
    assert_response :not_found
  end

  test "rechaza un profesor de otra universidad aunque se envíe su ID" do
    sign_in @admin

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(user: @other_professor)
    end
    assert_response :not_found
  end

  test "rechaza alumnos aunque se envíe su ID" do
    sign_in @admin

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(user: @student)
    end
    assert_response :not_found
  end

  test "no reemplaza al profesor existente" do
    ActsAsTenant.with_tenant(@university) { professor_assignment.save! }
    sign_in @admin

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(user: @second_professor)
    end

    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /ya tiene un profesor asignado/
    assert_equal @professor, SectionStaff.find_by!(section: @section, role: "profesor").user
  end

  test "director profesor ayudante y alumno no pueden consultar ni asignar" do
    [ @director, @professor, @assistant, @student ].each do |user|
      sign_in user

      get teacher_assignments_path
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]

      assert_no_difference "SectionStaff.count" do
        post teacher_assignments_path, params: assignment_params
      end
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]

      sign_out :user
    end
  end

  test "la otra universidad puede realizar su propia asignación" do
    sign_in @other_admin

    post teacher_assignments_path, params: assignment_params(section: @other_section, user: @other_professor)

    assert_redirected_to teacher_assignments_path
    assignment = SectionStaff.find_by!(section: @other_section, role: "profesor")
    assert_equal @other_professor, assignment.user
    assert_equal @other_admin, assignment.assigned_by
  end

  test "oculta y rechaza secciones con relaciones de otra universidad" do
    @section.update_columns(course_id: @other_section.course_id)
    sign_in @admin

    get teacher_assignments_path
    assert_response :success
    assert_select "tr#section_#{@section.id}", count: 0

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params
    end
    assert_response :not_found
  end

  test "no expone profesores de otra universidad en asignaciones antiguas inconsistentes" do
    professor_assignment(user: @other_professor).save!(validate: false)
    sign_in @admin

    get teacher_assignments_path

    assert_response :success
    assert_select "tr#section_#{@section.id}", text: /Asignación pendiente de revisión/
    assert_no_match @other_professor.name, response.body
  end

  test "muestra quién asignó al profesor y cuándo" do
    assignment = ActsAsTenant.with_tenant(@university) { professor_assignment.tap(&:save!) }
    sign_in @admin

    get teacher_assignments_path

    assert_select "tr#section_#{@section.id}",
      text: /Asignado por #{Regexp.escape(@admin.name)} el #{Regexp.escape(I18n.l(assignment.created_at.to_date))}/
  end

  # A22, coordinador: the profesor who coordinates a course assigns in its sections of the term they coordinate.

  test "el coordinador ve solo las secciones de su asignatura y período" do
    prepare_coordinator_data
    sign_in @coordinator

    get teacher_assignments_path

    assert_response :success
    assert_select "nav a[href=?]", teacher_assignments_path, text: "Asignar profesores"
    assert_select "p", text: /Secciones de las asignaturas que coordinas/
    assert_select "tr#section_#{@section.id}", count: 1
    [ @other_term_section, @other_course_section, @other_section ].each do |section|
      assert_select "tr#section_#{section.id}", count: 0
    end
    assert_select "option[value='#{@professor.id}']", text: @professor.name
    assert_select "option[value='#{@coordinator.id}']", text: @coordinator.name
    assert_select "option[value='#{@other_professor.id}']", count: 0
  end

  test "el coordinador asigna un profesor y la sección aparece en Mis cursos del profesor" do
    prepare_coordinator_data
    sign_in @coordinator

    assert_difference "SectionStaff.count", 1 do
      post teacher_assignments_path, params: assignment_params
    end
    assert_redirected_to teacher_assignments_path
    assignment = SectionStaff.find_by!(section: @section, role: "profesor")
    assert_equal @professor, assignment.user
    assert_equal @coordinator, assignment.assigned_by

    follow_redirect!
    assert_select "tr#section_#{@section.id}", text: /Asignado por #{Regexp.escape(@coordinator.name)}/
    sign_out :user

    sign_in @professor
    get courses_path
    assert_select "a[href=?]", ActsAsTenant.with_tenant(@university) { course_section_path(@section.course, @section) }
  end

  test "el coordinador puede asignarse a sí mismo" do
    prepare_coordinator_data
    sign_in @coordinator

    post teacher_assignments_path, params: assignment_params(user: @coordinator)

    assert_redirected_to teacher_assignments_path
    assert_equal @coordinator, SectionStaff.find_by!(section: @section, role: "profesor").user
  end

  test "el coordinador no asigna en otro período ni en otra asignatura aunque envíe el ID" do
    prepare_coordinator_data

    [ @other_term_section, @other_course_section ].each do |section|
      # A 404 raised on the first request after sign_in does not keep the session, so sign in each time.
      sign_in @coordinator
      assert_no_difference "SectionStaff.count" do
        post teacher_assignments_path, params: assignment_params(section: section)
      end
      assert_response :not_found
    end
  end

  test "el coordinador no reemplaza al profesor existente" do
    prepare_coordinator_data
    ActsAsTenant.with_tenant(@university) { professor_assignment.save! }
    sign_in @coordinator

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(user: @second_professor)
    end
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /ya tiene un profesor asignado/
  end

  test "un profesor que no coordina no ve el enlace ni puede asignar aunque exista un coordinador" do
    prepare_coordinator_data
    sign_in @professor

    get courses_path
    assert_select "nav a[href=?]", teacher_assignments_path, count: 0

    get teacher_assignments_path
    assert_response :redirect
    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(user: @second_professor)
    end
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  test "el coordinador no asigna secciones ni profesores de otra universidad" do
    prepare_coordinator_data
    create_cross_university_coordination
    sign_in @coordinator

    get teacher_assignments_path
    assert_select "tr#section_#{@other_section.id}", count: 0

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(section: @other_section, user: @other_professor)
    end
    assert_response :not_found

    sign_in @coordinator
    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(user: @other_professor)
    end
    assert_response :not_found
  end

  test "la cuenta de la otra sede de un coordinador no hereda la coordinación" do
    prepare_coordinator_data
    other_account = User.create!(first_name: @coordinator.first_name, last_name: @coordinator.last_name,
      rut: @coordinator.rut, email: "coordinador@otra.a22.test", password: "password123",
      role: "profesor", university: @other_university)
    sign_in other_account

    get teacher_assignments_path
    assert_response :redirect

    assert_no_difference "SectionStaff.count" do
      post teacher_assignments_path, params: assignment_params(section: @other_section, user: @other_professor)
    end
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  private

  def assignment_params(section: @section, user: @professor)
    { teacher_assignment: { section_id: section.id, user_id: user.id } }
  end
end
