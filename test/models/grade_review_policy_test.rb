require "test_helper"

# C2, C5, C6: only the profesor of the section reviews its grades; the ayudante and the alumno never do.
class GradeReviewPolicyTest < ActiveSupport::TestCase
  test "el profesor de la sección revisa las notas" do
    assert Ability.new(users(:profesor)).can?(:review_grades, evaluations(:one))
  end

  test "el ayudante, el alumno, el administrativo y el director no revisan notas" do
    %i[ayudante alumno administrativo director].each do |fixture|
      assert_not Ability.new(users(fixture)).can?(:review_grades, evaluations(:one)), "#{fixture} no debería revisar notas"
    end
  end

  test "el profesor de otra sección no revisa las notas de esta" do
    assert_not Ability.new(users(:profesor_iusa)).can?(:review_grades, evaluations(:one))
  end
end
