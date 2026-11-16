require "test_helper"

# T7: the domain tables are isolated by university like Course, Faculty, Section and Term (A3). With an active
# university a query only reaches its rows, and without one it raises instead of mixing both universities.
class TenantIsolationTest < ActiveSupport::TestCase
  MODELS = [
    CourseCoordinator, SectionStaff, Enrollment, Evaluation, Grade,
    AttendanceSession, AttendanceRecord, Notification, Announcement
  ].freeze

  MODELS.each do |model|
    test "#{model.table_name} solo muestra las filas de la universidad activa" do
      %i[ucv iusa].each do |slug|
        university = universities(slug)
        others = ActsAsTenant.without_tenant { model.where.not(university_id: university.id).count }
        assert_operator others, :>, 0, "faltan fixtures de #{model.table_name} en la otra universidad"

        ActsAsTenant.with_tenant(university) do
          assert model.exists?, "faltan fixtures de #{model.table_name} en #{slug}"
          assert_empty model.where.not(university_id: university.id), "#{model.table_name} muestra filas de otra universidad"
        end
      end
    end

    test "#{model.table_name} exige una universidad activa" do
      ActsAsTenant.current_tenant = nil

      assert_raises(ActsAsTenant::Errors::NoTenantSet) { model.first }
    end
  end

  test "un registro nuevo toma la universidad de su padre y no puede ser de otra" do
    evaluation = Evaluation.create!(section: sections(:one), name: "Control 2", weight: 10, due_on: Date.new(2026, 11, 20))
    assert_equal universities(:ucv), evaluation.university

    ActsAsTenant.with_tenant(universities(:iusa)) do
      other = Evaluation.new(section: sections(:one), name: "Control 3", weight: 10, due_on: Date.new(2026, 11, 20))

      assert_not other.valid?
    end
  end
end
