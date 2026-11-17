require "test_helper"

# C9: deleting the comment of a rejection withdraws that rejection: its grades go back to pending review, since a
# rejected grade always needs a comment (C6).
class RejectionCommentRemovalServiceTest < ActiveSupport::TestCase
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

  def remove(grade) = RejectionCommentRemovalService.new(grade: grade).call

  test "las notas del rechazo vuelven a pendiente, sin comentario ni revisor" do
    count = remove(@first)

    assert_equal 2, count
    [ @first, @second ].each do |grade|
      grade.reload
      assert grade.pendiente?
      assert_nil grade.rejection_comment
      assert_nil grade.reviewed_by
      assert_equal 4.0, grade.score
      assert_equal users(:ayudante), grade.entered_by
    end
  end

  test "no toca otro rechazo de la evaluación ni las notas ya corregidas o publicadas" do
    corrected = rejected(student("corregida", "10000005-9"), status: "pendiente")
    published = rejected(student("publicada", "10000006-7"), status: "publicada")
    other_rejection = rejected(student("otra", "10000007-5"), comment: "Falta la pregunta 4")

    assert_equal 2, remove(@first)

    assert_equal "Revisa la pregunta 2", corrected.reload.rejection_comment
    assert published.reload.publicada?
    assert other_rejection.reload.rechazada?
    assert_equal "Falta la pregunta 4", other_rejection.rejection_comment
  end
end
