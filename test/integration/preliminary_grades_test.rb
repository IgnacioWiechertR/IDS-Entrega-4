require "test_helper"

# C4: the ayudante of the section deletes a preliminary grade (pending or rejected) entered by mistake.
class PreliminaryGradesTest < ActionDispatch::IntegrationTest
  setup do
    @section = sections(:one)
    @evaluation = evaluations(:one)
    @grade = grades(:one) # the pending 5.5 of users(:alumno) in evaluations(:one)
  end

  def delete_grade(grade = @grade, evaluation: @evaluation, section: @section)
    delete section_evaluation_preliminary_grade_path(section, evaluation, grade)
  end

  def sheet_path = edit_section_evaluation_grade_sheet_path(@section, @evaluation)

  test "el ayudante elimina una nota pendiente y vuelve a la planilla" do
    sign_in users(:ayudante)

    assert_difference -> { Grade.count }, -1 do
      delete_grade
    end
    assert_redirected_to sheet_path
    assert_equal "Se eliminó la nota de #{users(:alumno).name}.", flash[:notice]

    follow_redirect!
    assert_select "input[name=?]", "entries[#{users(:alumno).id}][score]"
    assert_select "input[name=?][value]", "entries[#{users(:alumno).id}][score]", count: 0
  end

  test "el ayudante también elimina una nota rechazada" do
    @grade.update_columns(status: "rechazada", rejection_comment: "Revisa la pregunta 2")
    sign_in users(:ayudante)

    assert_difference -> { Grade.count }, -1 do
      delete_grade
    end
    assert_redirected_to sheet_path
  end

  test "una nota oficial no se elimina aunque se envíe el DELETE directamente" do
    @grade.update_columns(status: "publicada")
    sign_in users(:ayudante)

    assert_no_difference -> { Grade.count } do
      delete_grade
    end
    assert_redirected_to sheet_path
    assert_equal "Una nota oficial no se puede eliminar.", flash[:alert]
    assert @grade.reload.publicada?
  end

  test "el profesor, el alumno, el administrativo y el ayudante de otra sección no eliminan notas" do
    other_assistant = User.create!(first_name: "Ayudante", last_name: "Otra sección", rut: "10000012-1",
      email: "otra.seccion@ucv.test", password: "password123", role: "ayudante", university: universities(:ucv))
    other_section = Section.create!(course: courses(:three), term: terms(:one), number: 1)
    SectionStaff.create!(section: other_section, user: other_assistant, role: "ayudante", assigned_by: users(:administrativo))

    [ users(:profesor), users(:alumno), users(:administrativo), other_assistant ].each do |user|
      sign_in user
      assert_no_difference -> { Grade.count } do
        delete_grade
      end
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert], "#{user.email} no debería eliminar"
      sign_out :user
    end
  end

  test "una nota de otra evaluación no se elimina cambiando el id" do
    other_evaluation = Evaluation.create!(section: @section, name: "Control 3", weight: 10, due_on: Date.new(2026, 11, 20))
    sign_in users(:ayudante)

    assert_no_difference -> { Grade.count } do
      delete_grade(@grade, evaluation: other_evaluation)
    end
    assert_response :not_found
  end

  test "una nota de una sección de otra universidad responde 404" do
    sign_in users(:ayudante)
    iusa_grades = -> { ActsAsTenant.with_tenant(universities(:iusa)) { Grade.count } }

    assert_no_difference iusa_grades do
      delete_grade(grades(:two), evaluation: evaluations(:two), section: sections(:two))
    end
    assert_response :not_found
  end
end
