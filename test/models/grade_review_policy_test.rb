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

  # C8: only the profesor who rejected the grades edits the comment, while they are still rejected.
  def rejected_grade(reviewer: users(:profesor), status: "rechazada")
    grades(:one).tap { |grade| grade.update_columns(status: status, rejection_comment: "Revisa la pregunta 2", reviewed_by_id: reviewer.id) }
  end

  test "el profesor que rechazó edita el comentario mientras la nota siga rechazada" do
    assert Ability.new(users(:profesor)).can?(:edit_rejection_comment, rejected_grade)
    assert_not Ability.new(users(:profesor)).can?(:edit_rejection_comment, rejected_grade(status: "pendiente"))
  end

  test "un rechazo de otro profesor no lo edita el profesor actual de la sección" do
    former_profesor = User.create!(first_name: "Ex", last_name: "Profesor", rut: "10000008-3", email: "ex.profesor@ucv.test",
      password: "password123", role: "profesor", university: universities(:ucv))
    grade = rejected_grade(reviewer: former_profesor)

    assert_not Ability.new(users(:profesor)).can?(:edit_rejection_comment, grade)
    # The former profesor no longer teaches the section, so they cannot either.
    assert_not Ability.new(former_profesor).can?(:edit_rejection_comment, grade)
  end

  # C9: deleting the comment follows the same rule as editing it.
  test "solo el profesor que rechazó elimina el comentario, mientras la nota siga rechazada" do
    assert Ability.new(users(:profesor)).can?(:delete_rejection_comment, rejected_grade)
    assert_not Ability.new(users(:profesor)).can?(:delete_rejection_comment, rejected_grade(status: "pendiente"))

    former_profesor = User.create!(first_name: "Ex", last_name: "Profesor", rut: "10000008-3", email: "ex.profesor@ucv.test",
      password: "password123", role: "profesor", university: universities(:ucv))
    assert_not Ability.new(users(:profesor)).can?(:delete_rejection_comment, rejected_grade(reviewer: former_profesor))

    %i[ayudante alumno administrativo].each do |fixture|
      assert_not Ability.new(users(fixture)).can?(:delete_rejection_comment, rejected_grade), "#{fixture} no debería eliminarlo"
    end
  end

  test "el ayudante, el alumno y el administrativo no editan el comentario de rechazo" do
    grade = rejected_grade
    %i[ayudante alumno administrativo].each do |fixture|
      assert_not Ability.new(users(fixture)).can?(:edit_rejection_comment, grade), "#{fixture} no debería editarlo"
    end
  end
end
