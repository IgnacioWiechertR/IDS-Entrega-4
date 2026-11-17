require "test_helper"

# C8: from the grade review, the profesor who rejected the grades of an evaluation edits the rejection comment.
class RejectionCommentsTest < ActionDispatch::IntegrationTest
  setup do
    @section = sections(:one)
    @evaluation = Evaluation.create!(section: @section, name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @grade = rejected(users(:alumno))
  end

  def rejected(student, reviewer: users(:profesor), comment: "Revisa la pregunta 2")
    Grade.create!(evaluation: @evaluation, student: student, score: 4.0, status: "rechazada", rejection_comment: comment,
      entered_by: users(:ayudante), reviewed_by: reviewer)
  end

  def review_path = section_evaluation_grade_review_path(@section, @evaluation)

  def update_comment(comment, grade: @grade, evaluation: @evaluation, section: @section)
    patch section_evaluation_rejection_comment_path(section, evaluation, grade), params: { rejection_comment: comment }
  end

  test "el profesor ve cada rechazo con su comentario, quién rechazó y a qué alumnos afecta" do
    sign_in users(:profesor)
    get review_path

    assert_select "#rejection_#{@grade.id}" do
      assert_select "textarea[name=rejection_comment]", text: "Revisa la pregunta 2"
      assert_select "p", text: /Rechazada por #{users(:profesor).name}/
      assert_select "p", text: /#{users(:alumno).name}/
      assert_select "input[type=submit][value=?]", "Guardar comentario"
    end
  end

  test "el profesor que rechazó edita el comentario y el ayudante lo ve en su planilla" do
    sign_in users(:profesor)

    update_comment("Revisa la pregunta 2: falta justificar el resultado")

    assert_redirected_to review_path
    assert_equal "Comentario actualizado.", flash[:notice]
    assert @grade.reload.rechazada?
    assert_equal "Revisa la pregunta 2: falta justificar el resultado", @grade.rejection_comment
    sign_out :user

    sign_in users(:ayudante)
    get edit_section_evaluation_grade_sheet_path(@section, @evaluation)
    assert_select "#student_#{users(:alumno).id}", text: /«Revisa la pregunta 2: falta justificar el resultado»/
  end

  test "un comentario vacío no se guarda" do
    sign_in users(:profesor)

    update_comment("   ")

    assert_redirected_to review_path
    assert_equal "El comentario no puede quedar vacío.", flash[:alert]
    assert_equal "Revisa la pregunta 2", @grade.reload.rejection_comment
  end

  test "un rechazo de otro profesor se ve en solo lectura y no se puede editar" do
    former_profesor = User.create!(first_name: "Ex", last_name: "Profesor", rut: "10000008-3", email: "ex.profesor@ucv.test",
      password: "password123", role: "profesor", university: universities(:ucv))
    @grade.update_columns(reviewed_by_id: former_profesor.id)
    sign_in users(:profesor)

    get review_path
    assert_select "#rejection_#{@grade.id}" do
      assert_select "p", text: /Revisa la pregunta 2/
      assert_select "form", count: 0
    end

    update_comment("Cambiado por otro profesor")
    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
    assert_equal "Revisa la pregunta 2", @grade.reload.rejection_comment
  end

  test "el ayudante, el alumno y el administrativo no editan el comentario" do
    %i[ayudante alumno administrativo].each do |fixture|
      sign_in users(fixture)

      update_comment("Cambiado")

      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert], "#{fixture} no debería editarlo"
      sign_out :user
    end
    assert_equal "Revisa la pregunta 2", @grade.reload.rejection_comment
  end

  test "una nota de otra evaluación responde 404" do
    other = Evaluation.create!(section: @section, name: "Control 3", weight: 10, due_on: Date.new(2026, 11, 20))
    sign_in users(:profesor)

    update_comment("Cambiado", evaluation: other)

    assert_response :not_found
    assert_equal "Revisa la pregunta 2", @grade.reload.rejection_comment
  end

  test "una sección de otra universidad responde 404" do
    sign_in users(:profesor)
    iusa_grade = grades(:two) # rejected, in IUSA

    update_comment("Cambiado", grade: iusa_grade, evaluation: evaluations(:two), section: sections(:two))

    assert_response :not_found
    ActsAsTenant.with_tenant(universities(:iusa)) { assert_equal "Revisa la pregunta 2", iusa_grade.reload.rejection_comment }
  end
end
