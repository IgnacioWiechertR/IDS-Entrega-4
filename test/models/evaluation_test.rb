require "test_helper"

class EvaluationTest < ActiveSupport::TestCase
  def build_evaluation(**attributes)
    Evaluation.new({ section: sections(:one), name: "Control 2", weight: 20 }.merge(attributes))
  end

  test "nombre y ponderación son obligatorios" do
    evaluation = build_evaluation(name: "", weight: nil)

    assert_not evaluation.valid?
    assert evaluation.errors.added?(:name, :blank)
    assert evaluation.errors.added?(:weight, :blank)
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

    # sections(:two) only has evaluations(:two), worth 9.99.
    assert build_evaluation(section: sections(:two), weight: 90).valid?
  end
end
