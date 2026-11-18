require "test_helper"

# db/seeds/demo_volume.rb: many accounts, sections, grades, attendance, announcements, material and notifications in
# both universities, so every feature has something to show. Seeds create their own records (no fixtures).
class DemoVolumeSeedsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  PASSWORD = "demo-test-password".freeze

  setup do
    @previous = ENV.to_h.slice("SEED_PASSWORD", "SEED_ALUMNOS")
    ENV["SEED_PASSWORD"] = PASSWORD
    ENV["SEED_ALUMNOS"] = "30"
    travel_to Time.zone.local(2026, 11, 17, 12)
    start_from_empty_database
  end

  teardown do
    %w[SEED_PASSWORD SEED_ALUMNOS].each { |key| ENV[key] = @previous[key] }
    ActsAsTenant.current_tenant = nil
    travel_back
  end

  test "crea muchas cuentas de cada rol en ambas universidades y un director para las dos" do
    seed

    director = User.find_by!(email: "director@sga.test")
    assert director.director?
    assert_nil director.university

    each_university do |university|
      counts = User.count_by_role(university)
      assert_operator counts["administrativo"], :>=, 3
      assert_operator counts["profesor"], :>=, 10
      assert_operator counts["ayudante"], :>=, 8
      assert_operator counts["alumno"], :>=, 30
    end
    assert User.exists?(email: "alumno001@ucv.test", role: "alumno")
    assert User.exists?(email: "profesor01@iusa.test", role: "profesor")
  end

  test "las secciones vigentes tienen equipo, alumnos, notas en todos los estados y asistencia con correcciones" do
    seed

    each_university do
      sections = Section.where(term: Term.find_by!(name: "2026-2"))
      assert_operator sections.count, :>=, 12
      assert_operator SectionStaff.where(section: sections, role: "profesor").count, :>=, 10
      assert SectionStaff.where(section: sections, role: "ayudante").exists?
      assert Enrollment.where(section: sections, active: false).exists?, "debería haber alumnos retirados"

      grades = Grade.joins(:evaluation).where(evaluations: { section_id: sections.select(:id) })
      assert_equal %w[pendiente publicada rechazada], grades.distinct.pluck(:status).sort
      assert grades.where.not(points: nil).exists?
      assert grades.rechazada.where(rejection_comment: nil).none?
      assert grades.where(status: %w[publicada rechazada], reviewed_by_id: nil).none?
      assert Evaluation.where(section: sections).group(:section_id).sum(:weight).values.all? { |weight| weight <= 100 }

      records = AttendanceRecord.joins(:attendance_session).where(attendance_sessions: { section_id: sections.select(:id) })
      assert_equal %w[ausente presente], records.distinct.pluck(:status).sort
      assert records.where.not(corrected_by_id: nil).exists?, "debería haber marcas corregidas (B7)"
    end
  end

  test "hay anuncios del curso y de sección, material en .txt y notificaciones leídas y sin leer" do
    seed

    each_university do |university|
      assert Announcement.where(section_id: nil).exists?
      assert Announcement.where.not(section_id: nil).exists?

      materials = Material.where(course_id: Course.select(:id))
      assert_operator materials.count, :>=, 10
      materials.first(3).each do |material|
        assert material.file.attached?
        assert_equal 1, material.file.byte_size
        assert material.file.filename.to_s.end_with?(".txt")
        assert_equal university, material.uploaded_by.university
      end

      notifications = Notification.all
      assert_equal %w[nota_publicada notas_en_revision notas_rechazadas], notifications.distinct.pluck(:kind).sort
      assert notifications.where.not(read_at: nil).exists?
      assert notifications.unread.exists?
    end
  end

  test "D6 muestra secciones incompletas y el período anterior queda cerrado con historial de cuentas eliminadas" do
    seed

    each_university do |university|
      issues = DataCompletenessService.call(university: university).flat_map(&:issues)
      [ "Sin profesor asignado", "Sin alumnos activos", "Sin asistencia registrada" ].each do |issue|
        assert_includes issues, issue
      end

      past = Section.where(term: Term.find_by!(name: "2026-1"))
      past_grades = Grade.joins(:evaluation).where(evaluations: { section_id: past.select(:id) })
      assert past_grades.exists?
      assert_equal [ "publicada" ], past_grades.distinct.pluck(:status)
      assert AttendanceSession.where(section: past).exists?

      deleted = User.where(university: university, role: "alumno", active: false)
      assert deleted.exists?
      assert Enrollment.where(student: deleted, section: past).exists?
      assert Enrollment.where(student: deleted).where.not(section: past).none?
    end
  end

  # Grades, attendance and notifications are inserted in bulk, without validations: they must still be valid.
  test "las filas insertadas en bloque cumplen las validaciones de sus modelos" do
    seed

    each_university do
      [ Grade, AttendanceRecord, Notification ].each do |model|
        model.order(:id).limit(300).each do |record|
          assert record.valid?, "#{model.name}##{record.id}: #{record.errors.full_messages.to_sentence}"
        end
      end
    end
  end

  test "repetir la carga no duplica ni cambia nada" do
    seed
    account = User.find_by!(email: "alumno001@ucv.test")
    before = snapshot
    ENV["SEED_PASSWORD"] = "another-demo-password"

    seed

    assert_equal before, snapshot
    assert account.reload.valid_password?(PASSWORD)
  end

  test "las cuentas generadas inician sesión, las eliminadas no, y las cuentas demo tienen más cursos" do
    seed

    post user_session_path, params: { user: { email: "alumno001@ucv.test", password: PASSWORD } }
    assert_redirected_to courses_path
    delete destroy_user_session_path

    post user_session_path, params: { user: { email: "alumno015@ucv.test", password: PASSWORD } }
    get courses_path
    assert_redirected_to new_user_session_path

    sign_in User.find_by!(email: "alumno@ucv.test")
    get courses_path
    assert_response :success
    [ "Programación", "Cálculo I", "Estructuras de Datos", "Introducción a la Economía" ].each do |course|
      assert_includes response.body, course
    end
  end

  private

  # Other tests in the same parallel worker leave their fixtures in the database (a "ucv" with other courses,
  # terms and materials), and these assertions describe what the seeds build on an empty one. TRUNCATE is
  # transactional in PostgreSQL, so the test transaction brings the fixtures back afterwards.
  def start_from_empty_database
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} CASCADE")
  end

  def seed
    ActsAsTenant.without_tenant { capture_io { load Rails.root.join("db/seeds.rb") } }
  end

  def each_university
    %w[ucv iusa].each do |slug|
      university = University.find_by!(slug: slug)
      ActsAsTenant.with_tenant(university) { yield university }
    end
  end

  def snapshot
    ActsAsTenant.without_tenant do
      [ User, Section, SectionStaff, Enrollment, CourseCoordinator, Evaluation, Grade, AttendanceSession,
        AttendanceRecord, Announcement, Material, Notification ].to_h do |model|
        [ model.name, [ model.count, model.maximum(:id), model.maximum(:updated_at) ] ]
      end.merge("ActiveStorage::Attachment" => ActiveStorage::Attachment.count)
    end
  end
end
