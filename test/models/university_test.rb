require "test_helper"

class UniversityTest < ActiveSupport::TestCase
  test "el slug es único" do
    university = University.new(name: "Otra", slug: universities(:ucv).slug)

    assert_not university.valid?
    assert university.errors.added?(:slug, :taken, value: "ucv")
  end
end
