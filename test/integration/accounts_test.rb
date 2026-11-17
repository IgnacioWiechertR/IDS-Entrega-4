require "test_helper"

# A5: the list of accounts of the active university.
# A4: the administrativo creates one account at a time in their university. The system generates a temporary
# password and shows it only once, on the confirmation page.
class AccountsTest < ActionDispatch::IntegrationTest
  DENIED = "No tienes permiso para ver esa página.".freeze

  def account_params(**attributes)
    { first_name: "Josefa", last_name: "Muñoz", rut: "12.345.678-5", email: "josefa.munoz@ucv.test", role: "alumno" }
      .merge(attributes)
  end

  def create_account(**attributes)
    post accounts_path, params: { account: account_params(**attributes) }
  end

  test "el administrativo solo ve cuentas de su universidad" do
    sign_in users(:administrativo)

    get accounts_path

    assert_response :success

    within_ucv = %i[administrativo profesor ayudante alumno]

    within_ucv.each do |account|
      assert_select "tbody td", text: users(account).email, count: 1
    end

    %i[profesor_iusa alumno_iusa director].each do |account|
      assert_select "tbody td", text: users(account).email, count: 0
    end
  end

  test "el administrativo y el director ven el botón para crear una cuenta" do
    %i[administrativo director].each do |fixture|
      sign_in users(fixture)
      get accounts_path
      assert_select "a[href='#{new_account_path}']", text: "Crear cuenta"
      sign_out :user
    end
  end

  test "el formulario ofrece alumno, ayudante y profesor, con alumno por defecto" do
    sign_in users(:administrativo)

    get new_account_path
    assert_response :success
    assert_select "select#account_role option", count: 3
    assert_select "select#account_role option[selected][value=alumno]"
    %w[administrativo director].each { |role| assert_select "select#account_role option[value=#{role}]", count: 0 }
  end

  test "crea la cuenta en su universidad y muestra la contraseña temporal una sola vez" do
    sign_in users(:administrativo)

    assert_difference -> { User.count }, 1 do
      create_account
    end
    assert_response :created
    assert_includes response.headers["Cache-Control"], "no-store"

    account = User.find_by!(email: "josefa.munoz@ucv.test")
    assert_equal [ universities(:ucv), "alumno", "12345678-5", true ],
                 [ account.university, account.role, account.rut, account.active ]

    password = css_select("#temporary_password").text.strip
    assert_operator password.length, :>=, 12
    assert account.valid_password?(password)
    assert_nil flash[:notice]

    # The new person signs in with the temporary password.
    sign_out :user
    post user_session_path, params: { user: { email: "josefa.munoz@ucv.test", password: password } }
    assert_redirected_to courses_path
  end

  test "crea cuentas de profesor y de ayudante" do
    sign_in users(:administrativo)

    create_account(role: "profesor", rut: "10000001-6", email: "profe.nuevo@ucv.test")
    create_account(role: "ayudante", rut: "10000002-4", email: "ayudante.nuevo@ucv.test")

    assert_equal "profesor", User.find_by!(email: "profe.nuevo@ucv.test").role
    assert_equal "ayudante", User.find_by!(email: "ayudante.nuevo@ucv.test").role
  end

  test "no crea cuentas de administrativo ni de director" do
    sign_in users(:administrativo)

    %w[administrativo director].each do |role|
      assert_no_difference -> { User.count } do
        create_account(role: role)
      end
      assert_equal DENIED, flash[:alert]
    end
  end

  test "la cuenta queda en la universidad del administrativo aunque se envíe otra" do
    sign_in users(:administrativo)

    post accounts_path, params: { account: account_params.merge(university_id: universities(:iusa).id) }

    assert_equal universities(:ucv), User.find_by!(email: "josefa.munoz@ucv.test").university
  end

  test "muestra cada error junto a su campo" do
    sign_in users(:administrativo)

    assert_no_difference -> { User.count } do
      create_account(first_name: "", rut: "12.345.678-9", email: "sin-arroba")
    end
    assert_response :unprocessable_content
    assert_select "#account_first_name_error", text: /Nombre/
    assert_select "#account_rut_error", text: "RUT no es válido, revisa el número y el dígito verificador"
    assert_select "#account_email_error", text: /Correo/
    assert_select "#account_last_name_error", count: 0
    assert_select "input#account_last_name[value=?]", "Muñoz"
  end

  # A8: a repeated RUT in the same university names the account that already has it.
  test "un RUT repetido en la universidad indica la cuenta existente" do
    sign_in users(:administrativo)

    assert_no_difference -> { User.count } do
      create_account(rut: users(:alumno).rut)
    end
    assert_select "#account_rut_error", text: "RUT ya pertenece a la cuenta de Alumno UCV (alumno@ucv.test)"
  end

  test "el mismo RUT se puede usar en la otra universidad" do
    admin_iusa = User.create!(first_name: "Admin", last_name: "IUSA", rut: "22222222-2", email: "admin2@iusa.test",
                              password: "password123", role: "administrativo", university: universities(:iusa))
    sign_in admin_iusa

    assert_difference -> { User.where(university: universities(:iusa)).count }, 1 do
      create_account(rut: users(:ayudante).rut, email: "ayudante.nuevo@iusa.test")
    end
  end

  test "un correo ya usado se rechaza, aunque sea de la otra universidad" do
    sign_in users(:administrativo)

    assert_no_difference -> { User.count } do
      create_account(email: users(:alumno_iusa).email)
    end
    assert_select "#account_email_error"
  end

  # The director creates only administrativos: DirectorReadOnlyTest covers it.
  test "los demás roles no crean cuentas" do
    %i[profesor ayudante alumno].each do |fixture|
      sign_in users(fixture)

      get new_account_path
      assert_equal DENIED, flash[:alert], "#{fixture} no debería abrir el formulario"

      assert_no_difference -> { User.count } do
        create_account
      end
      assert_equal DENIED, flash[:alert], "#{fixture} no debería crear cuentas"

      sign_out :user
    end
  end

  test "busca por nombre completo sin distinguir mayusculas ni mezclar universidades" do
    sign_in users(:administrativo)

    get accounts_path, params: { q: "  pRoFeSoR uCv  " }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody td", text: users(:profesor).email
    assert_select "tbody td", text: users(:profesor_iusa).email, count: 0
  end

  test "busca el RUT con puntos guion o sin formato dentro de su universidad" do
    sign_in users(:administrativo)

    %w[33.333.333-3 33333333-3 333333333].each do |query|
      get accounts_path, params: { q: query }

      assert_response :success
      assert_select "tbody tr", count: 1
      assert_select "tbody td", text: users(:profesor).email
      assert_select "tbody td", text: users(:profesor_iusa).email, count: 0
    end
  end

  test "filtra por rol y lo combina con la busqueda" do
    sign_in users(:administrativo)

    get accounts_path, params: { role: "profesor" }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody td", text: users(:profesor).email

    get accounts_path, params: { q: "UCV", role: "alumno" }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody td", text: users(:alumno).email
    assert_select "input[name=q][value=UCV]"
    assert_select "select[name=role] option[selected][value=alumno]"
  end

  test "explica que no hay coincidencias cuando los filtros no encuentran cuentas" do
    sign_in users(:administrativo)

    [ { q: "zzzz" }, { role: "director" }, { q: "Profesor", role: "alumno" } ].each do |filters|
      get accounts_path, params: filters

      assert_response :success
      assert_select "tbody tr", count: 0
      assert_select "p", text: "No hay cuentas que coincidan con los filtros seleccionados en esta universidad."
      assert_select "p", text: "No hay cuentas registradas en esta universidad.", count: 0
    end
  end

  test "trata los comodines SQL como texto literal en la busqueda" do
    sign_in users(:administrativo)

    %w[% _].each do |query|
      get accounts_path, params: { q: query }

      assert_response :success
      assert_select "tbody tr", count: 0
    end
  end

  test "limpiar elimina la busqueda y el filtro de rol" do
    sign_in users(:administrativo)
    get accounts_path, params: { q: "Profesor", role: "alumno" }

    link = css_select("a").find { |element| element.text.strip == "Limpiar" }
    assert_not_nil link
    assert_equal accounts_path, link["href"]

    get link["href"]

    assert_response :success
    assert_select "tbody tr", count: 4
    assert_select "input[name=q]" do |inputs|
      assert_equal "", inputs.first["value"].to_s
    end
  end

  test "una universidad sin cuentas muestra el mensaje de listado vacio" do
    university = University.create!(name: "Universidad sin cuentas", slug: "sin-cuentas")
    sign_in users(:director)
    patch university_selection_path, params: { university_id: university.id }

    get accounts_path

    assert_response :success
    assert_select "tbody tr", count: 0
    assert_select "p", text: "No hay cuentas registradas en esta universidad."
  end

  test "pagina diez cuentas y conserva los filtros al avanzar y retroceder" do
    accounts = 11.times.map do |index|
      User.create!(
        first_name: "Pagina", last_name: format("Cuenta%02d", index),
        rut: Rut.build(20000000 + index), email: "pagina#{index}@ucv.test",
        role: "alumno", university: universities(:ucv), password: "password123"
      )
    end
    sign_in users(:administrativo)

    get accounts_path, params: { q: "Pagina", role: "alumno" }

    assert_response :success
    assert_select "tbody tr", count: 10
    accounts.first(10).each { |account| assert_select "tbody td", text: account.email }
    assert_select "tbody td", text: accounts.last.email, count: 0
    assert_select "nav[aria-label='Paginación de cuentas'] a", text: "Anterior", count: 0

    next_link = css_select("nav[aria-label='Paginación de cuentas'] a").find { |link| link.text == "Siguiente" }
    assert_not_nil next_link
    assert_equal({ "q" => "Pagina", "role" => "alumno", "page" => "2" },
                 Rack::Utils.parse_query(URI.parse(next_link["href"]).query))
    get next_link["href"]

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody td", text: accounts.last.email
    assert_select "nav[aria-label='Paginación de cuentas'] a", text: "Siguiente", count: 0

    previous_link = css_select("nav[aria-label='Paginación de cuentas'] a").find { |link| link.text == "Anterior" }
    assert_not_nil previous_link
    assert_equal({ "q" => "Pagina", "role" => "alumno", "page" => "1" },
                 Rack::Utils.parse_query(URI.parse(previous_link["href"]).query))
    get previous_link["href"]

    assert_response :success
    assert_select "tbody tr", count: 10
    assert_select "tbody td", text: accounts.first.email
    assert_select "tbody td", text: accounts.last.email, count: 0
  end

  # A16 / A17: role assignment and validation against incompatible section/course assignments.
  test "el administrativo cambia el rol de una cuenta sin asignaciones; el director no" do
    account = User.create!(
      first_name: "Lucas", last_name: "Méndez", rut: "10000010-5",
      email: "lucas.mendez@ucv.test", role: "alumno", university: universities(:ucv), password: "password123"
    )
    sign_in users(:administrativo)

    patch role_account_path(account), params: { account: { role: "ayudante" } }

    assert_redirected_to accounts_path
    assert_equal "ayudante", account.reload.role
    assert_match(/actualizado a Ayudante/, flash[:notice])

    sign_out :user
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }

    patch role_account_path(account), params: { account: { role: "profesor" } }

    assert_equal DENIED, flash[:alert]
    assert_equal "ayudante", account.reload.role
  end

  test "rechaza cambiar el rol de un profesor con secciones o coordinaciones activas" do
    profesor = User.create!(
      first_name: "Elena", last_name: "Rios", rut: "10000011-3",
      email: "elena.rios@ucv.test", role: "profesor", university: universities(:ucv), password: "password123"
    )
    course = Course.create!(university: universities(:ucv), faculty: faculties(:one), code: "TEST101", name: "Curso Prueba")
    section = Section.create!(university: universities(:ucv), course: course, term: terms(:one), number: 99)
    staff = SectionStaff.create!(
      university: universities(:ucv), section: section, user: profesor,
      role: "profesor", assigned_by: users(:administrativo)
    )
    coordinator = CourseCoordinator.create!(
      university: universities(:ucv), course: course, term: terms(:one),
      user: profesor, assigned_by: users(:administrativo)
    )

    sign_in users(:administrativo)

    patch role_account_path(profesor), params: { account: { role: "alumno" } }

    assert_redirected_to accounts_path
    assert_equal "profesor", profesor.reload.role
    assert_match(/profesor de sección y coordinador de curso/, flash[:alert])

    # Tras desvincularlo de la sección y la coordinación, el cambio sí procede.
    staff.destroy!
    coordinator.destroy!

    patch role_account_path(profesor), params: { account: { role: "alumno" } }

    assert_redirected_to accounts_path
    assert_equal "alumno", profesor.reload.role
  end

  test "rechaza cambiar el rol de un ayudante asignado a una sección" do
    ayudante = User.create!(
      first_name: "Diego", last_name: "Pardo", rut: "10000012-1",
      email: "diego.pardo@ucv.test", role: "ayudante", university: universities(:ucv), password: "password123"
    )
    course = Course.create!(university: universities(:ucv), faculty: faculties(:one), code: "TEST102", name: "Curso Ayudante")
    section = Section.create!(university: universities(:ucv), course: course, term: terms(:one), number: 99)
    staff = SectionStaff.create!(
      university: universities(:ucv), section: section, user: ayudante,
      role: "ayudante", assigned_by: users(:administrativo)
    )

    sign_in users(:administrativo)

    patch role_account_path(ayudante), params: { account: { role: "alumno" } }

    assert_redirected_to accounts_path
    assert_equal "ayudante", ayudante.reload.role
    assert_match(/ayudante de sección/, flash[:alert])

    staff.destroy!

    patch role_account_path(ayudante), params: { account: { role: "alumno" } }

    assert_redirected_to accounts_path
    assert_equal "alumno", ayudante.reload.role
  end

  test "rechaza cambiar el rol de un alumno con inscripciones activas" do
    alumno = User.create!(
      first_name: "Carla", last_name: "Soto", rut: "10000014-8",
      email: "carla.soto@ucv.test", role: "alumno", university: universities(:ucv), password: "password123"
    )
    course = Course.create!(university: universities(:ucv), faculty: faculties(:one), code: "TEST103", name: "Curso Alumno")
    section = Section.create!(university: universities(:ucv), course: course, term: terms(:one), number: 99)
    enrollment = Enrollment.create!(
      university: universities(:ucv), section: section, student: alumno, active: true
    )

    sign_in users(:administrativo)

    patch role_account_path(alumno), params: { account: { role: "ayudante" } }

    assert_redirected_to accounts_path
    assert_equal "alumno", alumno.reload.role
    assert_match(/alumno inscrito en secciones activas/, flash[:alert])

    enrollment.update!(active: false)

    patch role_account_path(alumno), params: { account: { role: "ayudante" } }

    assert_redirected_to accounts_path
    assert_equal "ayudante", alumno.reload.role
  end
end
