require "test_helper"

class GradeTest < ActiveSupport::TestCase
  def evaluation
    @evaluation ||= Evaluation.create!(section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
  end

  def build_grade(**attributes)
    Grade.new({ evaluation: evaluation, student: users(:alumno), score: 5.0, entered_by: users(:ayudante) }.merge(attributes))
  end

  test "una nota nueva queda pendiente" do
    assert_equal "pendiente", Grade.new.status
    assert build_grade.valid?
  end

  test "la nota va de 1.0 a 7.0" do
    [ 1.0, 4.5, 7.0 ].each { |score| assert build_grade(score: score).valid?, "#{score} debería ser válida" }
    [ 0.9, 7.1, nil ].each { |score| assert_not build_grade(score: score).valid?, "#{score.inspect} no debería ser válida" }
  end

  test "solo existen los estados pendiente, rechazada y publicada" do
    assert_equal %w[pendiente rechazada publicada], Grade.statuses.keys

    grade = build_grade(status: "aprobada")
    assert_not grade.valid?
    assert grade.errors.added?(:status, :inclusion, value: "aprobada")
  end

  test "al rechazar, el comentario es obligatorio" do
    grade = build_grade(status: "rechazada")
    assert_not grade.valid?
    assert grade.errors.added?(:rejection_comment, :blank)

    grade.rejection_comment = "Revisa la pregunta 2"
    assert grade.valid?
  end

  test "el puntaje es opcional y no puede ser negativo" do
    assert build_grade(points: nil).valid?
    assert build_grade(points: 42.5).valid?
    assert_not build_grade(points: -1).valid?
  end

  test "un alumno tiene una sola nota por evaluación" do
    build_grade.save!
    duplicate = build_grade(score: 6.0)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:student_id, :taken, value: users(:alumno).id)
  end

  test "el alumno es de la misma universidad que la evaluación" do
    grade = build_grade(student: users(:alumno_iusa))

    assert_not grade.valid?
    assert_includes grade.errors[:student], "debe ser de la misma universidad"
  end

  test "preliminares son las pendientes y rechazadas; publicadas, las oficiales" do
    publicada = build_grade(status: "publicada").tap(&:save!)

    assert_includes Grade.preliminares, grades(:one)
    assert_includes Grade.preliminares, grades(:two)
    assert_not_includes Grade.preliminares, publicada
    assert_equal [ publicada ], Grade.publicadas.to_a
  end
end
