require "test_helper"

# Seeds create their own records; this test does not need fixture insertion or privileged PostgreSQL triggers.
class DemoSeedsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @previous_password = ENV["SEED_PASSWORD"]
    ENV["SEED_PASSWORD"] = "demo-test-password"
    travel_to Time.zone.local(2026, 10, 30, 12)
  end

  teardown do
    ENV["SEED_PASSWORD"] = @previous_password
    ActsAsTenant.current_tenant = nil
    travel_back
  end

  test "ambas universidades tienen alumnos asistencia y los tres estados de notas" do
    seed_demo

    %w[ucv iusa].each do |slug|
      university = University.find_by!(slug: slug)
      ActsAsTenant.with_tenant(university) do
        section = demo_section(slug)
        assert_equal 3, section.active_students.count
        assert section.section_staffs.exists?(role: "ayudante")
        assert section.section_staffs.exists?(role: "profesor")
        assert_equal 8, section.attendance_sessions.count
        assert_equal 24, AttendanceRecord.where(attendance_session: section.attendance_sessions).count

        evaluations = section.evaluations.where("name LIKE ?", "Demo T8%")
        assert_equal 3, evaluations.count
        assert_equal 60, evaluations.sum(:weight)
        grades = Grade.where(evaluation: evaluations)
        assert_equal 9, grades.count
        assert_equal %w[pendiente publicada rechazada].sort, grades.distinct.pluck(:status).sort
        grades.each do |grade|
          assert_equal university.id, grade.student.university_id
          assert_equal university.id, grade.entered_by.university_id
          assert grade.rejection_comment.present? if grade.rechazada?
        end
      end
    end
  end

  test "repetir los seeds conserva las ediciones y no duplica registros" do
    seed_demo
    university = University.find_by!(slug: "ucv")
    account = User.find_by!(email: "alumno@ucv.test")
    account.update!(password: "changed-demo-password")
    encrypted_password = account.encrypted_password

    ActsAsTenant.with_tenant(university) do
      section = demo_section("ucv")
      grade = section.evaluations.find_by!(name: "Demo T8 · Control pendiente").grades.first!
      grade.update!(score: 6.8, status: "publicada", reviewed_by: User.find_by!(email: "profesor@ucv.test"))
      attendance = section.attendance_sessions.first!.attendance_records.first!
      attendance.update!(status: attendance.presente? ? "ausente" : "presente")
    end
    before = snapshot
    ENV["SEED_PASSWORD"] = "another-demo-password"

    seed_demo

    assert_equal before, snapshot
    assert_equal encrypted_password, account.reload.encrypted_password
  end

  test "los alumnos demo solo pueden consultar sus propias notas publicadas" do
    seed_demo

    %w[ucv iusa].each do |slug|
      sign_in User.find_by!(email: "alumno@#{slug}.test")
      get my_grades_path
      assert_response :success
      assert_select "a", text: "Demo T8 · Control publicado", count: 1
      assert_select "a", text: "Demo T8 · Control pendiente", count: 0
      assert_select "a", text: "Demo T8 · Control rechazado", count: 0

      student = User.find_by!(email: "alumno@#{slug}.test")
      unpublished = student.grades.pendiente.first!
      get my_grade_path(unpublished)
      assert_response :not_found

      other_grade = ActsAsTenant.without_tenant do
        other = User.find_by!(email: slug == "ucv" ? "alumno@iusa.test" : "alumno@ucv.test")
        other.grades.publicada.first!
      end
      get my_grade_path(other_grade)
      assert_response :not_found
      sign_out :user
    end
  end

  test "sin contraseña solo se crea la estructura academica" do
    ENV.delete("SEED_PASSWORD")
    before = User.count

    seed_demo

    assert_equal before, User.count
    assert University.exists?(slug: "ucv")
    assert University.exists?(slug: "iusa")
  end

  test "no altera evaluaciones existentes cuando falta ponderacion para los ejemplos" do
    ENV.delete("SEED_PASSWORD")
    seed_demo
    university = University.find_by!(slug: "ucv")
    ActsAsTenant.with_tenant(university) do
      demo_section("ucv").evaluations.create!(name: "Evaluación del usuario", weight: 50, due_on: Date.new(2026, 10, 15))
    end
    ENV["SEED_PASSWORD"] = "demo-test-password"

    output, = capture_io { ActsAsTenant.without_tenant { load Rails.root.join("db/seeds.rb") } }

    assert_includes output, "Se omiten las notas demo de ICC1001"
    ActsAsTenant.with_tenant(university) do
      evaluations = demo_section("ucv").evaluations
      assert_equal 50, evaluations.find_by!(name: "Evaluación del usuario").weight
      assert_equal 0, evaluations.where("name LIKE ?", "Demo T8%").count
    end
    ActsAsTenant.with_tenant(University.find_by!(slug: "iusa")) do
      assert_equal 3, demo_section("iusa").evaluations.where("name LIKE ?", "Demo T8%").count
    end
  end

  private

  def seed_demo
    ActsAsTenant.without_tenant do
      capture_io { load Rails.root.join("db/seeds.rb") }
    end
  end

  def demo_section(slug)
    course = Course.find_by!(code: slug == "ucv" ? "ICC1001" : "ANAT101")
    Section.find_by!(course: course, term: Term.find_by!(name: "2026-2"), number: 1)
  end

  def snapshot
    ActsAsTenant.without_tenant do
      [ University, Faculty, Term, Course, Section, User, SectionStaff, CourseCoordinator,
        Enrollment, Evaluation, Grade, AttendanceSession, AttendanceRecord ].to_h do |model|
        [ model.name, model.order(:id).map(&:attributes) ]
      end
    end
  end
end
