require "test_helper"

# What the client receives: db/seeds.rb without SEED_DEMO creates only the two universities and the director, so
# every other record is created from the app (director -> administrativos -> faculties, terms, courses, accounts).
class ClientSeedsTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @previous = ENV.to_h.slice("SEED_PASSWORD", "SEED_DEMO", "DIRECTOR_EMAIL")
    ENV["SEED_PASSWORD"] = "client-test-password"
    ENV.delete("SEED_DEMO")
    ENV.delete("DIRECTOR_EMAIL")
    start_from_empty_database
  end

  teardown do
    %w[SEED_PASSWORD SEED_DEMO DIRECTOR_EMAIL].each { |key| ENV[key] = @previous[key] }
    ActsAsTenant.current_tenant = nil
  end

  test "sin SEED_DEMO solo crea las dos universidades y la cuenta del director" do
    seed

    assert_equal %w[iusa ucv], University.order(:slug).pluck(:slug)
    director = User.sole
    assert_equal "director@sga.test", director.email
    assert director.director?
    assert_nil director.university
    assert director.valid_password?("client-test-password")
    ActsAsTenant.without_tenant do
      [ Faculty, Term, Course, Section, SectionStaff, Enrollment, CourseCoordinator, Evaluation, Grade ].each do |model|
        assert_equal 0, model.count, "#{model.name} debería quedar vacío"
      end
    end
  end

  test "DIRECTOR_EMAIL cambia el correo del director" do
    ENV["DIRECTOR_EMAIL"] = "direccion@cliente.test"

    seed

    assert_equal [ "direccion@cliente.test" ], User.pluck(:email)
  end

  test "sin SEED_PASSWORD no crea ninguna cuenta" do
    ENV.delete("SEED_PASSWORD")

    seed

    assert_equal 2, University.count
    assert_equal 0, User.count
  end

  test "repetir la carga no duplica ni cambia la contraseña del director" do
    seed
    ENV["SEED_PASSWORD"] = "another-password"

    seed

    assert_equal 1, User.count
    assert User.sole.valid_password?("client-test-password")
  end

  test "el director entra y puede crear el primer administrativo" do
    seed

    post user_session_path, params: { user: { email: "director@sga.test", password: "client-test-password" } }
    follow_redirect! while response.redirect?
    assert_response :success

    get new_account_path
    assert_response :success
  end

  private

  # Other tests in the same parallel worker leave their fixtures in the database. TRUNCATE is transactional in
  # PostgreSQL, so the test transaction brings them back afterwards.
  def start_from_empty_database
    connection = ActiveRecord::Base.connection
    tables = connection.tables - %w[schema_migrations ar_internal_metadata]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(', ')} CASCADE")
  end

  def seed
    ActsAsTenant.without_tenant { capture_io { load Rails.root.join("db/seeds.rb") } }
  end
end
