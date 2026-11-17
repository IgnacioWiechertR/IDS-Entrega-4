require "test_helper"

# Terms of a university: the administrativo creates, edits and deletes those of its own university, so the client
# can start from an empty app. The director only lists them; nobody else reaches them.
class TermsManagementTest < ActionDispatch::IntegrationTest
  setup do
    @term = terms(:one) # UCV, 2026-08-03..2026-12-11, not current
  end

  test "el administrativo crea un período de su universidad" do
    sign_in users(:administrativo)
    get terms_path
    assert_response :success
    assert_select "#terms", text: /Segundo semestre 2026/
    assert_select "#terms", text: /Anatomía|IUSA/, count: 0

    assert_difference "Term.count", 1 do
      post terms_path, params: { term: { name: "2027-1", starts_on: "2027-03-01", ends_on: "2027-07-16" } }
    end
    assert_redirected_to terms_path
    follow_redirect!
    assert_select "body", text: /El período 2027-1 fue creado/

    created = Term.find_by!(name: "2027-1")
    assert_equal universities(:ucv), created.university
    assert_not created.current
  end

  test "la universidad viene de la sesión, no del formulario" do
    sign_in users(:administrativo)

    post terms_path, params: { term: { name: "2027-1", starts_on: "2027-03-01", ends_on: "2027-07-16",
                                       university_id: universities(:iusa).id } }

    assert_equal universities(:ucv), Term.find_by!(name: "2027-1").university
  end

  test "rechaza nombres repetidos y fechas invertidas" do
    sign_in users(:administrativo)

    invalid = {
      "nombre repetido" => [ { name: "segundo semestre 2026", starts_on: "2027-03-01", ends_on: "2027-07-16" }, /Nombre ya está en uso/ ],
      "fin antes del inicio" => [ { name: "2027-1", starts_on: "2027-07-16", ends_on: "2027-03-01" }, /posterior a la fecha de inicio/ ]
    }
    invalid.each do |label, (params, message)|
      assert_no_difference "Term.count", label do
        post terms_path, params: { term: params }
      end
      assert_response :unprocessable_content, label
      assert_select "#error_explanation", { text: message }, label
    end
  end

  test "marcar un período como vigente desmarca el anterior" do
    @term.update!(current: true)
    sign_in users(:administrativo)

    post terms_path, params: { term: { name: "2027-1", starts_on: "2027-03-01", ends_on: "2027-07-16", current: "1" } }

    assert_redirected_to terms_path
    assert Term.find_by!(name: "2027-1").current
    assert_not @term.reload.current
    assert terms(:two).reload.current == false, "no toca los períodos de la otra universidad"
    ActsAsTenant.with_tenant(universities(:ucv)) { assert_equal 1, Term.where(current: true).count }
  end

  test "un período inválido marcado como vigente no desmarca el actual" do
    @term.update!(current: true)
    sign_in users(:administrativo)

    post terms_path, params: { term: { name: "", starts_on: "2027-03-01", ends_on: "2027-07-16", current: "1" } }

    assert_response :unprocessable_content
    assert @term.reload.current
  end

  test "el administrativo edita un período" do
    sign_in users(:administrativo)

    get edit_term_path(@term)
    assert_response :success
    patch term_path(@term), params: { term: { name: "2026-2", ends_on: "2026-12-18" } }

    assert_redirected_to terms_path
    assert_equal [ "2026-2", Date.new(2026, 12, 18) ], [ @term.reload.name, @term.ends_on ]
  end

  test "solo se elimina un período sin secciones ni coordinadores" do
    sign_in users(:administrativo)

    assert_no_difference "Term.count" do
      delete term_path(@term)
    end
    assert_redirected_to terms_path
    follow_redirect!
    assert_select "body", text: /No se puede eliminar el período Segundo semestre 2026 porque tiene secciones/
    assert Section.exists?(sections(:one).id)

    empty = Term.create!(university: universities(:ucv), name: "2027-1", starts_on: "2027-03-01", ends_on: "2027-07-16")
    assert_difference "Term.count", -1 do
      delete term_path(empty)
    end
    assert_redirected_to terms_path
  end

  # A 404 does not keep the test session (Devise test helpers), so each request signs in again.
  test "un período de la otra universidad no se ve ni se modifica" do
    sign_in users(:administrativo)
    get edit_term_path(terms(:two))
    assert_response :not_found

    sign_in users(:administrativo)
    patch term_path(terms(:two)), params: { term: { name: "Cambiado" } }
    assert_response :not_found

    sign_in users(:administrativo)
    delete term_path(terms(:two))
    assert_response :not_found
    assert_equal "Segundo semestre 2026", terms(:two).reload.name
  end

  test "el director ve los períodos de la universidad activa sin modificarlos" do
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }

    get terms_path
    assert_response :success
    assert_select "#terms", text: /Segundo semestre 2026/
    assert_select "a", text: "Nuevo período", count: 0
    assert_select "#terms a, #terms button", text: /Editar|Eliminar/, count: 0

    assert_no_difference "Term.count" do
      post terms_path, params: { term: { name: "2027-1", starts_on: "2027-03-01", ends_on: "2027-07-16" } }
    end
    assert_redirected_to dashboard_path
    patch term_path(@term), params: { term: { name: "Cambiado" } }
    assert_equal "Segundo semestre 2026", @term.reload.name
  end

  test "profesor ayudante y alumno no entran" do
    %i[profesor ayudante alumno].each do |role|
      sign_in users(role)
      get terms_path
      assert_response :redirect, role.to_s
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      sign_out :user
    end
  end
end
