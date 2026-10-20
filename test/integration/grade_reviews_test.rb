require "test_helper"

# C2: the profesor of the section sees the pending grades of an evaluation.
# C5: approves them all at once (they become official). C6: rejects them with a mandatory comment.
class GradeReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @section = sections(:one)
    @evaluation = Evaluation.create!(section: @section, name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @grade = Grade.create!(evaluation: @evaluation, student: users(:alumno), score: 5.0, feedback: "Bien",
                           entered_by: users(:ayudante))
  end

  def review_path = section_evaluation_grade_review_path(@section, @evaluation)
  def approve_path = approve_section_evaluation_grade_review_path(@section, @evaluation)
  def reject_path = reject_section_evaluation_grade_review_path(@section, @evaluation)

  test "el profesor ve las notas pendientes de revisión de la evaluación" do
    sign_in users(:profesor)
    get review_path

    assert_response :success
    assert_select "h1", text: /Control 2/
    assert_select "#grade_#{@grade.id}", text: /Alumno UCV.*5,0.*Bien.*Ayudante UCV/m
    assert_select "#grade_#{@grade.id}", text: /Pendiente de revisión/
  end

  test "al aceptar, las notas quedan publicadas y se avisa a cada alumno" do
    sign_in users(:profesor)

    assert_enqueued_with(job: GradesPublishedNotificationJob, args: [ @evaluation, [ users(:alumno).id ] ]) do
      post approve_path
    end
    assert_redirected_to review_path
    assert_equal "1 nota aprobada y publicada.", flash[:notice]
    assert @grade.reload.publicada?
  end

  test "al rechazar con comentario, las notas quedan rechazadas y se avisa al ayudante" do
    sign_in users(:profesor)

    assert_enqueued_with(job: GradesRejectedNotificationJob, args: [ @evaluation, [ users(:ayudante).id ], 1, "Revisa la pregunta 2" ]) do
      post reject_path, params: { rejection_comment: "Revisa la pregunta 2" }
    end
    assert_redirected_to review_path
    assert_equal "1 nota rechazada. Se avisó al ayudante.", flash[:notice]
    assert @grade.reload.rechazada?
    assert_equal "Revisa la pregunta 2", @grade.rejection_comment
  end

  test "rechazar sin comentario no cambia nada y lo pide" do
    sign_in users(:profesor)

    assert_no_enqueued_jobs do
      post reject_path, params: { rejection_comment: "  " }
    end
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /Debes escribir un comentario para rechazar las notas/
    assert @grade.reload.pendiente?
  end

  test "sin notas pendientes se indica y los botones quedan deshabilitados" do
    @grade.update!(status: "publicada")
    sign_in users(:profesor)
    get review_path

    assert_select "#no-pending", text: /No hay notas pendientes de revisión/
    assert_select "form[action=?] button[disabled]", approve_path, text: "Aceptar notas"
    assert_select "form[action=?] input[type=submit][value=?][disabled]", reject_path, "Rechazar notas"
  end

  test "una nota fuera de 1.0–7.0 impide publicar" do
    @grade.update_columns(score: 7.5)
    sign_in users(:profesor)

    post approve_path
    assert_equal "Hay notas fuera de 1,0–7,0: no se publicó ninguna.", flash[:alert]
    assert @grade.reload.pendiente?
  end

  test "el ayudante, el alumno y el administrativo no revisan notas" do
    %i[ayudante alumno administrativo].each do |fixture|
      sign_in users(fixture)

      get review_path
      assert_response :redirect, "#{fixture} no debería ver la revisión"
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]

      post approve_path
      post reject_path, params: { rejection_comment: "No" }
      assert @grade.reload.pendiente?, "#{fixture} no debería cambiar las notas"

      sign_out :user
    end
  end

  test "una sección de otra universidad responde 404" do
    sign_in users(:profesor_iusa)

    get review_path
    assert_response :not_found
  end

  test "la lista de evaluaciones muestra Revisar notas solo al profesor" do
    sign_in users(:profesor)
    get section_evaluations_path(@section)
    assert_select "a[href=?]", review_path, text: "Revisar notas (1 pendiente)"
    sign_out :user

    sign_in users(:ayudante)
    get section_evaluations_path(@section)
    assert_select "a[href=?]", review_path, count: 0
  end
end
