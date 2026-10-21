require "test_helper"

# C13: the profesor or the ayudante of a section creates its evaluations and sees them listed.
class EvaluationsTest < ActionDispatch::IntegrationTest
  def evaluation_params(**attributes)
    { evaluation: { name: "Control 1", weight: "20", due_on: "2026-11-05", rubric: "Pregunta 1: 2 puntos" }.merge(attributes) }
  end

  def section = sections(:one)

  test "el profesor de la sección ve sus evaluaciones y la ponderación asignada" do
    sign_in users(:profesor)
    get section_evaluations_path(section)

    assert_response :success
    assert_select "h1", text: /Programación/
    assert_select "#evaluations tr", text: /#{evaluations(:one).name}/
    assert_select "#weight_total", text: /9,99 % de 100 %/
  end

  test "el profesor crea una evaluación y queda en la lista" do
    sign_in users(:profesor)

    assert_difference -> { section.evaluations.count }, 1 do
      post section_evaluations_path(section), params: evaluation_params
    end
    assert_redirected_to section_evaluations_path(section)

    follow_redirect!
    assert_select "[role=status]", text: "Evaluación creada."
    assert_select "#evaluations tr", text: /Control 1/
    assert_select "#weight_total", text: /29,99 % de 100 %/
  end

  test "el ayudante de la sección también crea evaluaciones" do
    sign_in users(:ayudante)

    assert_difference -> { section.evaluations.count }, 1 do
      post section_evaluations_path(section), params: evaluation_params(name: "Tarea 1", rubric: "")
    end
  end

  test "el formulario muestra cuánto queda disponible" do
    sign_in users(:profesor)
    get new_section_evaluation_path(section)

    assert_response :success
    assert_select "#weight_available", text: /90,01 %/
  end

  test "si la suma pasa del 100 % no se guarda y se explica" do
    sign_in users(:profesor)

    assert_no_difference -> { Evaluation.count } do
      post section_evaluations_path(section), params: evaluation_params(weight: "95")
    end
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /Ponderación supera el 100 % de la sección \(queda 90,01 % disponible\)/
  end

  test "nombre, ponderación y fecha son obligatorios" do
    sign_in users(:profesor)

    assert_no_difference -> { Evaluation.count } do
      post section_evaluations_path(section), params: evaluation_params(name: "", weight: "", due_on: "")
    end
    assert_response :unprocessable_content
    %w[Nombre Ponderación Fecha].each do |attribute|
      assert_select "[role=alert]", text: /#{attribute} no puede estar en blanco/
    end
  end

  test "un alumno inscrito y el administrativo no ven ni crean evaluaciones" do
    %i[alumno administrativo].each do |fixture|
      sign_in users(fixture)

      get section_evaluations_path(section)
      assert_response :redirect, "#{fixture} no debería ver la lista"
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]

      assert_no_difference -> { Evaluation.count } do
        post section_evaluations_path(section), params: evaluation_params
      end
      assert_response :redirect

      sign_out :user
    end
  end

  test "el profesor de otra sección no ve ni crea evaluaciones en esta" do
    other_professor = User.create!(first_name: "Otra", last_name: "Profesora", rut: "77777777-7",
      email: "otra.profesora@ucv.test", password: "password123", role: "profesor", university: universities(:ucv))
    ActsAsTenant.with_tenant(universities(:ucv)) do
      other_section = Section.create!(course: courses(:three), term: terms(:one), number: 1)
      SectionStaff.create!(section: other_section, user: other_professor, role: "profesor", assigned_by: users(:administrativo))
    end
    sign_in other_professor

    get section_evaluations_path(section)
    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]

    assert_no_difference -> { Evaluation.count } do
      post section_evaluations_path(section), params: evaluation_params
    end
  end

  test "una sección de otra universidad responde 404" do
    sign_in users(:profesor_iusa)

    get section_evaluations_path(section)
    assert_response :not_found

    # An error page does not write the session cookie, so sign in again for the next request.
    sign_in users(:profesor_iusa)
    assert_no_difference -> { Evaluation.count } do
      post section_evaluations_path(section), params: evaluation_params
    end
    assert_response :not_found
  end

  test "la sección muestra el acceso a evaluaciones solo al equipo docente" do
    sign_in users(:profesor)
    get course_section_path(courses(:one), section)
    assert_select "a[href=?]", section_evaluations_path(section), text: "Evaluaciones"
    sign_out :user

    sign_in users(:alumno)
    get course_section_path(courses(:one), section)
    assert_select "a[href=?]", section_evaluations_path(section), count: 0
  end
end
