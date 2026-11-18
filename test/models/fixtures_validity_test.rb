require "test_helper"

# T7: every fixture is valid inside its own university, and the accounts it points to (student, author,
# who entered or reviewed it...) belong to that university. The director has none, so it may appear in any.
class FixturesValidityTest < ActiveSupport::TestCase
  MODELS = [
    Faculty, Term, Course, Section, CourseCoordinator, SectionStaff, Enrollment, Evaluation, Grade,
    AttendanceSession, AttendanceRecord, Notification, Announcement
  ].freeze

  test "las cuentas de las fixtures son válidas" do
    User.find_each { |user| assert user.valid?, "users #{user.email}: #{user.errors.full_messages.to_sentence}" }
  end

  MODELS.each do |model|
    test "las fixtures de #{model.table_name} son válidas y no cruzan universidades" do
      University.find_each do |university|
        ActsAsTenant.with_tenant(university) do
          model.where(university: university).find_each do |record|
            assert record.valid?, "#{model.name}##{record.id}: #{record.errors.full_messages.to_sentence}"
            assert_accounts_in(university, record)
          end
        end
      end
    end
  end

  private

  def assert_accounts_in(university, record)
    record.class.reflect_on_all_associations(:belongs_to).select { |association| association.class_name == "User" }.each do |association|
      person = record.public_send(association.name)
      next if person.nil? || person.director?

      assert_equal university.id, person.university_id,
        "#{record.class.name}##{record.id}.#{association.name} (#{person.email}) es de otra universidad"
    end
  end
end
