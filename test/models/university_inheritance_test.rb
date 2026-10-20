require "test_helper"

# Every domain table stores its university, and it is always the university of the record it belongs to.
class UniversityInheritanceTest < ActiveSupport::TestCase
  # model => [parent association, builder of a new record whose parent is in UCV]
  CASES = {
    CourseCoordinator => [ :course, -> { CourseCoordinator.new(course: courses(:one), term: terms(:one), user: users(:profesor), assigned_by: users(:administrativo)) } ],
    SectionStaff => [ :section, -> { SectionStaff.new(section: sections(:one), user: users(:profesor), role: "profesor", assigned_by: users(:administrativo)) } ],
    Enrollment => [ :section, -> { Enrollment.new(section: sections(:one), student: users(:alumno)) } ],
    Evaluation => [ :section, -> { Evaluation.new(section: sections(:one), name: "Control 1", weight: 20, due_on: Date.new(2026, 11, 5)) } ],
    Grade => [ :evaluation, -> { Grade.new(evaluation: evaluations(:one), student: users(:alumno), score: 5.0, entered_by: users(:ayudante)) } ],
    AttendanceSession => [ :section, -> { AttendanceSession.new(section: sections(:one), held_on: Date.current, recorded_by: users(:profesor)) } ],
    AttendanceRecord => [ :attendance_session, -> { AttendanceRecord.new(attendance_session: attendance_sessions(:one), student: users(:alumno), status: "presente") } ],
    Notification => [ :recipient, -> { Notification.new(recipient: users(:alumno), kind: "nota_publicada", message: "Tienes una nota nueva") } ]
  }.freeze

  test "cada registro toma la universidad de su padre" do
    CASES.each do |model, (_parent, build)|
      record = instance_exec(&build)
      record.valid?

      assert_equal universities(:ucv), record.university, "#{model} debería tomar la universidad de su padre"
    end
  end

  test "rechaza una universidad distinta a la de su padre" do
    CASES.each do |model, (_parent, build)|
      record = instance_exec(&build)
      record.university = universities(:iusa)

      assert_not record.valid?, "#{model} no debería aceptar otra universidad"
      assert_includes record.errors[:university], "debe ser la misma del registro al que pertenece"
    end
  end

  test "la universidad es obligatoria en la base de datos" do
    CASES.each_key do |model|
      assert_not model.columns_hash.fetch("university_id").null, "#{model}.university_id debería ser NOT NULL"
    end
  end

  test "las fixtures tienen la universidad de su padre" do
    ActsAsTenant.without_tenant do
      CASES.each do |model, (parent, _build)|
        model.find_each do |record|
          assert_equal record.public_send(parent).university_id, record.university_id, "#{model} ##{record.id}"
        end
      end
    end
  end
end
