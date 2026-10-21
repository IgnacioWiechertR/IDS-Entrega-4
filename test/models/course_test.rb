require "test_helper"

class CourseTest < ActiveSupport::TestCase
  def build_course(**attributes)
    Course.new({ university: universities(:ucv), faculty: faculties(:one), code: "ICC2001", name: "Bases de Datos" }.merge(attributes))
  end

  test "código y nombre son obligatorios" do
    course = build_course(code: "", name: "")

    assert_not course.valid?
    assert course.errors.added?(:code, :blank)
    assert course.errors.added?(:name, :blank)
  end

  test "el código es único dentro de la universidad" do
    duplicate = build_course(code: courses(:one).code)

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:code, :taken, value: courses(:one).code)
  end

  test "el mismo código puede existir en la otra universidad" do
    ActsAsTenant.with_tenant(universities(:iusa)) do
      assert build_course(code: courses(:one).code, university: universities(:iusa), faculty: faculties(:two)).valid?
    end
  end

  test "la facultad es de la misma universidad" do
    course = build_course(faculty: faculties(:two))

    assert_not course.valid?
    assert_includes course.errors[:faculty], "debe ser de la misma universidad"
  end

  test "se elimina un curso sin registros asociados" do
    assert courses(:three).destroy
  end

  test "no se elimina un curso con secciones, coordinadores, materiales o avisos" do
    course = courses(:one)

    assert_not course.destroy
    assert course.errors[:base].any?
    assert Course.exists?(course.id)
  end
end
