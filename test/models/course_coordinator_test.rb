require "test_helper"

class CourseCoordinatorTest < ActiveSupport::TestCase
  def next_term(university)
    ActsAsTenant.with_tenant(universities(university)) do
      # Term names are unique per university: a test that asks twice gets the same term.
      Term.find_or_create_by!(university: universities(university), name: "2027-1") do |term|
        term.starts_on = Date.new(2027, 3, 1)
        term.ends_on = Date.new(2027, 7, 15)
      end
    end
  end

  def build_coordinator(**attributes)
    CourseCoordinator.new({ course: courses(:one), term: next_term(:ucv), user: users(:profesor), assigned_by: users(:administrativo) }.merge(attributes))
  end

  test "un curso tiene un solo coordinador por período" do
    duplicate = build_coordinator(term: terms(:one))

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:course_id, :taken, value: courses(:one).id)
  end

  test "el coordinador es una cuenta de profesor" do
    assert build_coordinator.valid?

    coordinator = build_coordinator(user: users(:alumno))
    assert_not coordinator.valid?
    assert_includes coordinator.errors[:user], "debe ser una cuenta de profesor"
  end

  test "el coordinador es de la misma universidad que el curso" do
    # An IUSA course, inside IUSA, with the UCV account of the profesor.
    ActsAsTenant.with_tenant(universities(:iusa)) do
      coordinator = build_coordinator(course: courses(:two), term: next_term(:iusa), assigned_by: users(:administrativo_iusa))

      assert_not coordinator.valid?
      assert_includes coordinator.errors[:user], "debe ser de la misma universidad"
    end
  end

  test "el período es de la misma universidad que el curso" do
    coordinator = build_coordinator(term: next_term(:iusa))

    assert_not coordinator.valid?
    assert_includes coordinator.errors[:term], "debe ser de la misma universidad"
  end

  test "un profesor puede coordinar varios cursos" do
    course = Course.create!(university: universities(:ucv), faculty: faculties(:one), code: "ICC2001", name: "Bases de Datos")

    assert build_coordinator(course: course, term: terms(:one)).valid?
  end
end
