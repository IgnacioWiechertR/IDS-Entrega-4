require "test_helper"

class TermTest < ActiveSupport::TestCase
  def build_term(**attributes)
    Term.new({ university: universities(:ucv), name: "2027-1", starts_on: Date.new(2027, 3, 1), ends_on: Date.new(2027, 7, 15) }.merge(attributes))
  end

  test "nombre y fechas son obligatorios" do
    term = build_term(name: "", starts_on: nil, ends_on: nil)

    assert_not term.valid?
    %i[name starts_on ends_on].each { |attribute| assert term.errors.added?(attribute, :blank) }
  end

  test "el período termina después de empezar" do
    term = build_term(ends_on: Date.new(2027, 2, 1))

    assert_not term.valid?
    assert_includes term.errors[:ends_on], "debe ser posterior a la fecha de inicio"
  end

  test "un período nuevo no queda vigente por defecto" do
    assert_not Term.new.current?
  end

  test "solo hay un período vigente por universidad" do
    terms(:one).update!(current: true)

    other = build_term(current: true)
    assert_not other.valid?
    assert_includes other.errors[:current], "ya hay otro período vigente en la universidad"

    assert build_term(current: false).valid?
    assert build_term(current: true, university: universities(:iusa)).valid?
  end
end
