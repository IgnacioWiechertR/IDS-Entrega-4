require "test_helper"

class AnnouncementsEditTest < ActionDispatch::IntegrationTest
  test "el profesor del curso edita asunto y mensaje y se muestra cuándo se editó" do
    announcement = announcements(:one)
    published_at = 1.day.ago
    announcement.update_columns(created_at: published_at, updated_at: published_at)

    sign_in users(:profesor)
    get announcement_path(announcement)
    assert_response :success
    assert_select "a[href=?]", edit_announcement_path(announcement), text: "Editar anuncio"
    assert_select "dt", text: "Editado:", count: 0

    get edit_announcement_path(announcement)
    assert_response :success
    assert_select "input[name='announcement[subject]'][value=?]", announcement.subject
    assert_select "textarea[name='announcement[body]']", text: announcement.body
    assert_select "input[name='announcement[section_id]']", count: 0
    assert_select "select[name='announcement[section_id]']", count: 0

    patch announcement_path(announcement), params: { announcement: { subject: "Nueva sala", body: "Ahora será en B-202." } }
    assert_response :see_other
    assert_redirected_to announcement_path(announcement)
    announcement.reload
    assert_equal "Nueva sala", announcement.subject
    assert_equal "Ahora será en B-202.", announcement.body
    assert_operator announcement.updated_at, :>, announcement.created_at

    follow_redirect!
    assert_select "h1", text: "Nueva sala"
    assert_select "#announcement_body", text: "Ahora será en B-202."
    assert_select "dt", text: "Editado:"
    assert_select "dd", text: I18n.l(announcement.updated_at, format: "%d/%m/%Y %H:%M")

    get announcements_path
    assert_select "#announcement_#{announcement.id} dt", text: "Editado:"
  end

  test "asunto y mensaje siguen siendo obligatorios al editar" do
    announcement = announcements(:one)
    sign_in users(:profesor)

    patch announcement_path(announcement), params: { announcement: { subject: " ", body: " " } }

    assert_response :unprocessable_content
    assert_select "#error_explanation", text: /Asunto no puede estar en blanco/
    assert_select "#error_explanation", text: /Mensaje no puede estar en blanco/
    assert_select "input[type=submit][value='Guardar cambios']"
    assert_equal "Cambio de sala", announcement.reload.subject
  end

  test "solo se pueden cambiar asunto y mensaje" do
    announcement = announcements(:one)
    sign_in users(:profesor)

    patch announcement_path(announcement), params: { announcement: {
      subject: "Corrección", body: "Mensaje corregido", course_id: courses(:three).id,
      section_id: nil, author_id: users(:ayudante).id, university_id: universities(:iusa).id
    } }

    assert_response :see_other
    announcement.reload
    assert_equal courses(:one), announcement.course
    assert_equal sections(:one), announcement.section
    assert_equal users(:profesor), announcement.author
    assert_equal universities(:ucv), announcement.university
  end

  test "ayudantes alumnos y administrativos no pueden editar" do
    announcement = announcements(:one)

    %i[ayudante alumno administrativo].each do |role|
      sign_in users(role)
      get edit_announcement_path(announcement)
      assert_response :redirect, "#{role} no debería abrir el formulario"

      patch announcement_path(announcement), params: { announcement: { subject: "Intruso", body: "Cambio" } }
      assert_response :redirect, "#{role} no debería guardar cambios"
      assert_equal "Cambio de sala", announcement.reload.subject
      sign_out :user
    end
  end

  test "un profesor ajeno al curso no puede editar el anuncio" do
    unrelated = User.create!(first_name: "Otra", last_name: "Profesora", rut: Rut.build(17_234_567),
      email: "otra.profesora@ucv.test", password: "password123", role: "profesor", university: universities(:ucv))
    announcement = announcements(:one)
    sign_in unrelated

    get edit_announcement_path(announcement)
    assert_response :redirect
    patch announcement_path(announcement), params: { announcement: { subject: "Intruso", body: "Cambio" } }
    assert_response :redirect
    assert_equal "Cambio de sala", announcement.reload.subject
  end

  test "un profesor de otra universidad no puede editar el anuncio" do
    sign_in users(:profesor_iusa)
    announcement = announcements(:one)

    get edit_announcement_path(announcement)
    assert_response :not_found
    sign_in users(:profesor_iusa)
    patch announcement_path(announcement), params: { announcement: { subject: "Intruso", body: "Cambio" } }
    assert_response :not_found
    assert_equal "Cambio de sala", ActsAsTenant.with_tenant(universities(:ucv)) { announcement.reload.subject }
  end
end
