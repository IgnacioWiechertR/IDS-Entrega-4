require "test_helper"

class UniversityTest < ActiveSupport::TestCase
  test "el slug es único" do
    university = University.new(name: "Otra", slug: universities(:ucv).slug, size: "grande")

    assert_not university.valid?
    assert university.errors.added?(:slug, :taken, value: "ucv")
  end

  test "el tamaño solo puede ser grande o pequena" do
    assert_not University.new(name: "Otra", slug: "otra", size: "mediana").valid?
    assert University.new(name: "Otra", slug: "otra", size: "pequena").valid?
  end
end
