require "test_helper"

class SectionTest < ActiveSupport::TestCase
  def build_section(**attributes)
    Section.new({ university: universities(:ucv), course: courses(:one), term: terms(:one), number: 2 }.merge(attributes))
  end

  test "el número es un entero positivo" do
    assert build_section.valid?
    [ nil, 0, -1, 1.5 ].each { |number| assert_not build_section(number: number).valid?, "#{number.inspect} no debería ser válido" }
  end

  test "no se repite el número en el mismo curso y período" do
    duplicate = build_section(number: sections(:one).number)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:number, :taken, value: sections(:one).number)
  end

  test "el curso y el período son de la misma universidad" do
    section = build_section(course: courses(:two), term: terms(:two))

    assert_not section.valid?
    assert_includes section.errors[:course], "debe ser de la misma universidad"
    assert_includes section.errors[:term], "debe ser de la misma universidad"
  end
end
