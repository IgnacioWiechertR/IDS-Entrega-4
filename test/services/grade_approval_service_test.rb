require "test_helper"
require "benchmark"

# C5: "Aceptar notas" publishes the pending grades of an evaluation in a single operation.
class GradeApprovalServiceTest < ActiveSupport::TestCase
  setup do
    @evaluation = Evaluation.create!(section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
  end

  def approve(evaluation = @evaluation) = GradeApprovalService.new(evaluation: evaluation, reviewer: users(:profesor)).call

  def add_grade(student, status: "pendiente", score: 5.0, comment: nil)
    Grade.create!(evaluation: @evaluation, student: student, score: score, status: status,
                  rejection_comment: comment, entered_by: users(:ayudante))
  end

  def new_student(last_name, rut)
    User.create!(first_name: "Alumna", last_name: last_name, rut: rut, email: "#{last_name.downcase}@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
  end

  test "publica todas las notas pendientes y deja registro de quién las aprobó" do
    first = add_grade(users(:alumno))
    second = add_grade(new_student("Rojas", "10000001-6"), score: 6.5)

    result = approve

    assert result.success?
    assert_equal 2, result.count
    assert_equal [ first.student_id, second.student_id ].sort, result.student_ids.sort
    [ first, second ].each do |grade|
      assert grade.reload.publicada?
      assert_equal users(:profesor), grade.reviewed_by
    end
  end

  test "no toca las rechazadas ni las ya publicadas" do
    rejected = add_grade(users(:alumno), status: "rechazada", comment: "Revisa la pregunta 2")
    published = add_grade(new_student("Rojas", "10000001-6"), status: "publicada")
    pending = add_grade(new_student("Soto", "10000002-4"))

    result = approve

    assert_equal 1, result.count
    assert pending.reload.publicada?
    assert rejected.reload.rechazada?
    assert_nil published.reload.reviewed_by
  end

  test "sin notas pendientes no publica nada" do
    result = approve

    assert_not result.success?
    assert_equal :none_pending, result.error
    assert_equal 0, result.count
  end

  test "si alguna nota está fuera de 1.0–7.0 no publica ninguna" do
    valid = add_grade(users(:alumno))
    invalid = add_grade(new_student("Rojas", "10000001-6"))
    invalid.update_columns(score: 7.5) # data that skipped the validations

    result = approve

    assert_not result.success?
    assert_equal :out_of_range, result.error
    assert valid.reload.pendiente?
    assert invalid.reload.pendiente?
  end

  test "publica 100 notas en menos de 3 segundos" do
    now = Time.current
    rows = (1..100).map do |i|
      { first_name: "Alumno", last_name: "N#{i}", rut: Rut.build(30_000_000 + i), email: "alumno#{i}@carga.test", role: "alumno",
        university_id: universities(:ucv).id, encrypted_password: "", active: true, created_at: now, updated_at: now }
    end
    student_ids = User.insert_all!(rows, returning: :id).rows.flatten
    Grade.insert_all!(student_ids.map do |id|
      { evaluation_id: @evaluation.id, student_id: id, score: 5.0, status: "pendiente", entered_by_id: users(:ayudante).id,
        university_id: @evaluation.university_id, created_at: now, updated_at: now }
    end)

    result = nil
    elapsed = Benchmark.realtime { result = approve }

    assert_equal 100, result.count
    assert_operator elapsed, :<, 3, "tomó #{elapsed.round(2)} s"
  end
end
