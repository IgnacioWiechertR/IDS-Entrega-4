require "test_helper"

class EvaluationTest < ActiveSupport::TestCase
  def build_evaluation(**attributes)
    Evaluation.new({ section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5) }.merge(attributes))
  end

  test "nombre, ponderación y fecha son obligatorios" do
    evaluation = build_evaluation(name: "", weight: nil, due_on: nil)

    assert_not evaluation.valid?
    assert evaluation.errors.added?(:name, :blank)
    assert evaluation.errors.added?(:weight, :blank)
    assert evaluation.errors.added?(:due_on, :blank)
  end

  test "la pauta es opcional" do
    assert build_evaluation(rubric: nil).valid?
  end

  # C14: the maximum score is optional; with it, a score is converted to a grade with a 50 % passing threshold.
  test "el puntaje máximo es opcional y mayor que 0" do
    assert build_evaluation(max_points: nil).valid?
    assert build_evaluation(max_points: 60).valid?
    [ 0, -10 ].each { |points| assert_not build_evaluation(max_points: points).valid?, "#{points} no debería ser válido" }
  end

  test "convierte el puntaje a nota con 50 % de exigencia" do
    evaluation = build_evaluation(max_points: 60)

    { 0 => 1.0, 15 => 2.5, 30 => 4.0, 44 => 5.4, 60 => 7.0, 7 => 1.7, 52.5 => 6.3 }.each do |points, grade|
      assert_equal BigDecimal(grade.to_s), evaluation.score_for(points), "#{points} de 60 debería ser #{grade}"
    end
    assert_equal 30, evaluation.passing_points
  end

  test "sin puntaje máximo no hay conversión" do
    evaluation = build_evaluation(max_points: nil)

    assert_nil evaluation.score_for(40)
    assert_nil evaluation.passing_points
  end

  test "la ponderación es mayor que 0 y hasta 100" do
    [ 0, -5, 100.01 ].each { |weight| assert_not build_evaluation(weight: weight).valid?, "#{weight} no debería ser válida" }
    assert build_evaluation(weight: 0.01).valid?
  end

  test "la suma de ponderaciones de la sección no supera el 100 %" do
    # evaluations(:one) already weighs 9.99 in this section.
    build_evaluation(weight: 90).save!

    over = build_evaluation(weight: 0.02)
    assert_not over.valid?
    assert_includes over.errors[:weight], "supera el 100 % de la sección (queda 0,01 % disponible)"

    assert build_evaluation(weight: 0.01).valid?
  end

  test "al editar, la evaluación no se suma a sí misma" do
    assert evaluations(:one).update(weight: 100)
  end

  test "las evaluaciones de otra sección no cuentan" do
    build_evaluation(weight: 90).save!

    # sections(:two) only has evaluations(:two), worth 9.99. It is an IUSA section, so it is checked inside IUSA.
    ActsAsTenant.with_tenant(universities(:iusa)) do
      assert build_evaluation(section: sections(:two), weight: 90).valid?
    end
  end
end
