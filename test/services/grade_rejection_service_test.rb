require "test_helper"

# C6: "Rechazar notas" sends the pending grades of an evaluation back to the ayudante, with a mandatory comment.
class GradeRejectionServiceTest < ActiveSupport::TestCase
  setup do
    @evaluation = Evaluation.create!(section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @grade = Grade.create!(evaluation: @evaluation, student: users(:alumno), score: 5.0, entered_by: users(:ayudante))
  end

  def reject(comment) = GradeRejectionService.new(evaluation: @evaluation, reviewer: users(:profesor), comment: comment).call

  test "deja las notas pendientes en rechazada con el comentario y quién las rechazó" do
    result = reject("  Revisa la pregunta 2  ")

    assert result.success?
    assert_equal 1, result.count
    assert_equal [ users(:ayudante).id ], result.assistant_ids
    @grade.reload
    assert @grade.rechazada?
    assert_equal "Revisa la pregunta 2", @grade.rejection_comment
    assert_equal users(:profesor), @grade.reviewed_by
  end

  test "el comentario es obligatorio" do
    [ nil, "", "   " ].each do |comment|
      result = reject(comment)

      assert_not result.success?
      assert_equal :comment_required, result.error
    end
    assert @grade.reload.pendiente?
  end

  test "sin notas pendientes no rechaza nada" do
    @grade.update!(status: "publicada")

    result = reject("Revisa la pregunta 2")

    assert_equal :none_pending, result.error
    assert @grade.reload.publicada?
  end
end
