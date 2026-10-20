require "test_helper"

# C1 (Trello): "Solo los ayudantes de la sección pueden ingresar notas". The profesor approves or rejects them.
class GradePolicyTest < ActiveSupport::TestCase
  def ability_for(user) = Ability.new(user)

  test "el ayudante de la sección ingresa notas" do
    assert ability_for(users(:ayudante)).can?(:enter_grades, evaluations(:one))
  end

  test "el profesor, el alumno, el administrativo y el director no ingresan notas" do
    %i[profesor alumno administrativo director].each do |fixture|
      assert_not ability_for(users(fixture)).can?(:enter_grades, evaluations(:one)), "#{fixture} no debería ingresar notas"
    end
  end

  test "el ayudante de otra sección no ingresa notas en esta" do
    other_assistant = User.create!(first_name: "Otra", last_name: "Ayudante", rut: "88888888-8", email: "otra.ayudante@ucv.test",
      password: "password123", role: "ayudante", university: universities(:ucv))
    other_section = Section.create!(course: courses(:three), term: terms(:one), number: 1)
    SectionStaff.create!(section: other_section, user: other_assistant, role: "ayudante", assigned_by: users(:administrativo))

    assert_not ability_for(other_assistant).can?(:enter_grades, evaluations(:one))
  end
end
