require "test_helper"
require_relative "../support/coordinator_assignment_data"

class CoordinatorAssignmentsTest < ActionDispatch::IntegrationTest
  include CoordinatorAssignmentData

  setup { prepare_coordinator_assignment_data }
  teardown { ActsAsTenant.current_tenant = nil }

  test "la consulta y asignación exigen iniciar sesión" do
    get course_coordinators_path
    assert_redirected_to new_user_session_path

    assert_no_difference "CourseCoordinator.count" do
      post course_coordinators_path, params: assignment_params
    end
    assert_redirected_to new_user_session_path
  end

  test "el administrativo ve solo asignaturas profesores y períodos de su universidad" do
    sign_in @admin
    get course_coordinators_path

    assert_response :success
    assert_select "h1", "Asignar coordinador"
    assert_select "nav a[href=?]", course_coordinators_path, text: "Asignar coordinadores"
    assert_select "tr#course_#{@course.id}", count: 1
    assert_select "tr#course_#{@other_course.id}", count: 0
    assert_select "select[name='term_id'] option[selected][value=?]", @term.id
    assert_select "select[name='term_id'] option[value=?]", @other_term.id, count: 0
    assert_select "select[name='course_coordinator[user_id]'] option[value=?]", @professor.id, text: @professor.name
    assert_select "select[name='course_coordinator[user_id]'] option[value=?]", @other_professor.id, count: 0
    assert_select "select[name='course_coordinator[user_id]'] option[value=?]", @student.id, count: 0
  end

  test "el administrativo asigna y la asignación aparece después de recargar" do
    sign_in @admin

    assert_difference "CourseCoordinator.count", 1 do
      post course_coordinators_path, params: assignment_params
    end
    assert_response :see_other
    assert_redirected_to course_coordinators_path(term_id: @term.id)

    assignment = CourseCoordinator.find_by!(course: @course, term: @term)
    assert_equal @professor, assignment.user
    assert_equal @admin, assignment.assigned_by
    assert_equal @university, assignment.university
    follow_redirect!
    assert_select "tr#course_#{@course.id} li", text: @professor.name
  end

  test "el director asigna en la universidad activa y puede cambiar a la otra" do
    sign_in @director
    select_university(@university)
    get course_coordinators_path
    assert_response :success
    assert_select "nav a[href=?]", course_coordinators_path, count: 1

    post course_coordinators_path, params: assignment_params
    assert_redirected_to course_coordinators_path(term_id: @term.id)
    assert_equal @director, CourseCoordinator.find_by!(course: @course, term: @term).assigned_by

    select_university(@other_university)
    get course_coordinators_path
    assert_response :success
    assert_select "tr#course_#{@other_course.id}", count: 1
    assert_select "tr#course_#{@course.id}", count: 0

    post course_coordinators_path,
      params: assignment_params(course: @other_course, term: @other_term, user: @other_professor)
    assert_redirected_to course_coordinators_path(term_id: @other_term.id)
    assignment = CourseCoordinator.find_by!(course: @other_course, term: @other_term)
    assert_equal @director, assignment.assigned_by
    assert_equal @other_university, assignment.university
  end

  test "el director no cruza universidades mediante IDs sin cambiar la universidad activa" do
    sign_in @director
    select_university(@university)

    assert_no_difference "CourseCoordinator.count" do
      post course_coordinators_path,
        params: assignment_params(course: @other_course, term: @other_term, user: @other_professor)
    end
    assert_response :not_found
  end

  test "se ignoran la universidad y el autor enviados desde el formulario" do
    sign_in @admin
    attributes = assignment_params
    attributes[:course_coordinator].merge!(university_id: @other_university.id, assigned_by_id: @director.id)

    post course_coordinators_path, params: attributes

    assert_redirected_to course_coordinators_path(term_id: @term.id)
    assignment = CourseCoordinator.find_by!(course: @course, term: @term)
    assert_equal @admin, assignment.assigned_by
    assert_equal @university, assignment.university
  end

  test "el administrativo no puede enviar asignaturas de otra universidad" do
    sign_in @admin

    assert_no_difference "CourseCoordinator.count" do
      post course_coordinators_path, params: assignment_params(course: @other_course)
    end
    assert_response :not_found
  end

  test "rechaza profesores de otra universidad" do
    sign_in @admin

    assert_no_difference "CourseCoordinator.count" do
      post course_coordinators_path, params: assignment_params(user: @other_professor)
    end
    assert_response :not_found
  end

  test "rechaza períodos de otra universidad en consulta y asignación" do
    sign_in @admin
    get accounts_path
    assert_response :success
    get course_coordinators_path(term_id: @other_term.id)
    assert_response :not_found

    assert_no_difference "CourseCoordinator.count" do
      post course_coordinators_path, params: assignment_params(term: @other_term)
    end
    assert_response :not_found
  end

  test "rechaza cuentas que no son profesores" do
    sign_in @admin
    get accounts_path
    assert_response :success

    [ @student, @assistant, @admin, @director ].each do |user|
      assert_no_difference "CourseCoordinator.count" do
        post course_coordinators_path, params: assignment_params(user: user)
      end
      assert_response :not_found
    end
  end

  test "profesor ayudante y alumno no pueden consultar ni asignar" do
    [ @professor, @assistant, @student ].each do |user|
      sign_in user
      get course_coordinators_path
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]

      assert_no_difference "CourseCoordinator.count" do
        post course_coordinators_path, params: assignment_params
      end
      assert_response :redirect
      sign_out :user
    end
  end

  test "cada período conserva sus propias asignaciones" do
    sign_in @admin
    post course_coordinators_path, params: assignment_params
    post course_coordinators_path, params: assignment_params(term: @past_term, user: @second_professor)
    assert_redirected_to course_coordinators_path(term_id: @past_term.id)

    get course_coordinators_path(term_id: @past_term.id)
    assert_select "tr#course_#{@course.id} li", text: @second_professor.name
    assert_select "tr#course_#{@course.id} li", text: @professor.name, count: 0
  end

  test "una colisión con la restricción heredada muestra errores sin reemplazar datos" do
    ActsAsTenant.with_tenant(@university) { coordinator_assignment.save! }
    sign_in @admin

    assert_no_difference "CourseCoordinator.count" do
      post course_coordinators_path, params: assignment_params(user: @second_professor)
    end
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /ya tiene un coordinador/
    assert_equal @professor, CourseCoordinator.find_by!(course: @course, term: @term).user
  end

  test "el profesor asignado puede encontrar el curso que coordina en Mis cursos" do
    sign_in @admin
    post course_coordinators_path, params: assignment_params
    sign_out :user
    sign_in @professor

    get courses_path

    assert_response :success
    assert_select "a[href=?]", course_path(@course, term_id: @term.id)
    assert_match "Coordinador", response.body
  end

  test "no hay rutas para modificar o eliminar coordinadores desde el scaffold" do
    sign_in @admin

    get "/course_coordinators/new"
    assert_response :not_found
    patch "/course_coordinators/123", params: assignment_params
    assert_response :not_found
    delete "/course_coordinators/123"
    assert_response :not_found
  end

  private

  def select_university(university)
    patch university_selection_path, params: { university_id: university.id }
    assert_response :redirect
  end

  def assignment_params(course: @course, term: @term, user: @professor)
    { course_coordinator: { course_id: course.id, term_id: term.id, user_id: user.id } }
  end
end
