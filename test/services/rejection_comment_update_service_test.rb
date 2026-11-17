require "test_helper"

# C8: the profesor who rejected the grades of an evaluation edits the comment of that rejection.
class RejectionCommentUpdateServiceTest < ActiveSupport::TestCase
  setup do
    @evaluation = Evaluation.create!(section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @first = rejected(users(:alumno))
    @second = rejected(student("segunda", "10000004-0"))
  end

  def student(name, rut)
    User.create!(first_name: name.capitalize, last_name: "Alumna", rut: rut, email: "#{name}@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
  end

  def rejected(student, comment: "Revisa la pregunta 2", reviewer: users(:profesor), status: "rechazada")
    Grade.create!(evaluation: @evaluation, student: student, score: 4.0, status: status, rejection_comment: comment,
      entered_by: users(:ayudante), reviewed_by: reviewer)
  end

  def update(grade, comment) = RejectionCommentUpdateService.new(grade: grade, comment: comment).call

  test "cambia el comentario de todas las notas de ese rechazo, que siguen rechazadas" do
    result = update(@first, "  Revisa la pregunta 2: falta justificar el resultado  ")

    assert result.success?
    assert_equal 2, result.count
    [ @first, @second ].each do |grade|
      grade.reload
      assert grade.rechazada?
      assert_equal "Revisa la pregunta 2: falta justificar el resultado", grade.rejection_comment
    end
  end

  test "un comentario vacío no se guarda" do
    [ nil, "", "   " ].each do |comment|
      result = update(@first, comment)

      assert_not result.success?
      assert_equal :comment_required, result.error
    end
    assert_equal "Revisa la pregunta 2", @first.reload.rejection_comment
  end

  test "no toca las notas ya corregidas o publicadas, ni otro rechazo de la evaluación" do
    corrected = rejected(student("corregida", "10000005-9"), status: "pendiente")
    published = rejected(student("publicada", "10000006-7"), status: "publicada")
    other_rejection = rejected(student("otra", "10000007-5"), comment: "Falta la pregunta 4")
    former_profesor = User.create!(first_name: "Ex", last_name: "Profesor", rut: "10000008-3", email: "ex.profesor@ucv.test",
      password: "password123", role: "profesor", university: universities(:ucv))
    by_someone_else = rejected(student("ajena", "10000009-1"), reviewer: former_profesor)

    result = update(@first, "Comentario nuevo")

    assert_equal 2, result.count
    assert_equal "Revisa la pregunta 2", corrected.reload.rejection_comment
    assert_equal "Revisa la pregunta 2", published.reload.rejection_comment
    assert_equal "Falta la pregunta 4", other_rejection.reload.rejection_comment
    assert_equal "Revisa la pregunta 2", by_someone_else.reload.rejection_comment
  end
end
