require "test_helper"
require "csv"
require "stringio"

class AccountCsvImportTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup do
    @universities = {}
    %i[ucv iusa].each do |key|
      @universities[key] = University.create!(name: "CSV #{key}", slug: "csv-#{key}")
    end
    @users = {}
    %i[administrativo director profesor ayudante alumno].each_with_index do |role, index|
      @users[role] = User.create!(first_name: "CSV", last_name: role.to_s,
        rut: Rut.build(29000000 + index), email: "csv-#{role}@example.test",
        password: "test-password-123", role: role,
        university: role == :director ? nil : @universities[:ucv])
    end
  end

  teardown { ActsAsTenant.current_tenant = nil }

  def csv_file(content)
    file = Tempfile.new([ "accounts", ".csv" ])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "text/csv")
  ensure
    file&.close
  end

  test "imports valid rows and rejects invalid duplicates without changing existing accounts" do
    sign_in @users[:administrativo]
    content = CSV.generate do |csv|
      csv << %w[nombre rut correo rol]
      csv << [ "Ana Pérez", "12345678-5", "csv@example.test", "" ]
      csv << [ "Otra Persona", "12345678-5", "otra@example.test", "alumno" ]
      csv << [ "Otra Persona", "10000001-6", "csv@example.test", "profesor" ]
      csv << [ "Sin Apellido", "12345678-9", "invalid@example.test", "alumno" ]
      csv << [ "Otro Admin", "10000002-4", "admin.csv@example.test", "administrativo" ]
      csv << [ "Otro Profesor", "10000003-2", "prof.csv@example.test", "profesor" ]
    end
    assert_difference -> { User.count }, 2 do
      post import_accounts_path, params: { file: csv_file(content), university_id: @universities[:iusa].id }
    end
    assert_response :success
    assert_includes response.headers["Cache-Control"], "no-store"
    account = User.find_by!(email: "csv@example.test")
    assert_equal @universities[:ucv], account.university
    assert_equal "alumno", account.role
    assert account.valid_password?(css_select(".temporary-password").first.text)
    assert_no_difference -> { User.count } do
      post import_accounts_path, params: { file: csv_file(content) }
    end
  end

  test "form and example are available only to administrators" do
    sign_in @users[:administrativo]
    get import_accounts_path
    assert_response :success
    assert_select "input[type=file][name=file]"
    get sample_csv_accounts_path
    assert_response :success
    assert_equal %w[nombre rut correo rol], CSV.parse(response.body).first
    %i[director profesor ayudante alumno].each do |role|
      sign_in @users[role]
      get import_accounts_path
      assert_response :redirect
      get sample_csv_accounts_path
      assert_response :redirect
      assert_no_difference -> { User.count } do
        post import_accounts_path
      end
      assert_response :redirect
    end
  end

  test "invalid files create nothing and show a useful message" do
    sign_in @users[:administrativo]
    [ "", "nombre,rut,correo\n", "wrong,headers\na,b\n",
      "nombre,rut,correo\n\"unterminated", "x" * (1.megabyte + 1) ].each do |content|
      assert_no_difference -> { User.count } do
        post import_accounts_path, params: { file: csv_file(content) }
      end
      assert_response :unprocessable_content
      assert_select "[role=alert]"
    end
    post import_accounts_path
    assert_response :unprocessable_content
  end

  test "BOM and optional role work and the same RUT is allowed in another university" do
    actor = @users[:administrativo]
    result = AccountCsvImporter.new(actor: actor).call(StringIO.new(
      "\uFEFFnombre,rut,correo\nNueva Persona,10000001-6,bom@example.test\n"))
    assert_equal 1, result.created.size
    assert_equal "alumno", result.created.first[:account].role
    actor.update!(university: @universities[:iusa])
    result = AccountCsvImporter.new(actor: actor).call(StringIO.new(
      "nombre,rut,correo\nNueva Persona,10000001-6,other@example.test\n"))
    assert_equal 1, result.created.size
    assert_equal @universities[:iusa], result.created.first[:account].university
  end
end
