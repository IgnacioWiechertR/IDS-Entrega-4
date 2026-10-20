require "test_helper"

# C13: only the teaching staff of a section (profesor or ayudante) creates and lists its evaluations.
class EvaluationPolicyTest < ActiveSupport::TestCase
  def ability_for(fixture) = Ability.new(users(fixture))

  def new_evaluation(section = sections(:one)) = Evaluation.new(section: section)

  test "el profesor y el ayudante de la sección crean y ven sus evaluaciones" do
    %i[profesor ayudante].each do |fixture|
      assert ability_for(fixture).can?(:create, new_evaluation), "#{fixture} debería poder crear"
      assert ability_for(fixture).can?(:read, evaluations(:one)), "#{fixture} debería poder ver"
    end
  end

  test "un alumno inscrito y el administrativo no crean ni ven evaluaciones" do
    %i[alumno administrativo director].each do |fixture|
      assert_not ability_for(fixture).can?(:create, new_evaluation), "#{fixture} no debería poder crear"
      assert_not ability_for(fixture).can?(:read, evaluations(:one)), "#{fixture} no debería poder ver"
    end
  end

  test "el equipo docente de otra sección no crea evaluaciones en esta" do
    ActsAsTenant.with_tenant(universities(:iusa)) do
      assert ability_for(:profesor_iusa).can?(:create, new_evaluation(sections(:two)))
    end
    assert_not ability_for(:profesor_iusa).can?(:create, new_evaluation)
  end

  test "la lista solo trae las evaluaciones de las secciones propias" do
    visible = Evaluation.accessible_by(ability_for(:profesor))

    assert_includes visible, evaluations(:one)
    assert_not_includes visible, evaluations(:two)
  end
end
