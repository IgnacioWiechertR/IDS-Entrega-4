require "test_helper"

class AnnouncementsDeleteTest < ActionDispatch::IntegrationTest
  test "el profesor ve la confirmación y al eliminar el anuncio desaparece para quienes podían leerlo" do
    announcement = announcements(:one)
    sign_in users(:profesor)

    get announcement_path(announcement)
    assert_response :success
    assert_select "form[action=?][data-turbo-confirm]", announcement_path(announcement), 1 do
      assert_select "button", text: "Eliminar anuncio"
    end
    assert_match "Esta acción no se puede deshacer.", response.body

    assert_difference "Announcement.count", -1 do
      delete announcement_path(announcement)
    end
    assert_response :see_other
    assert_redirected_to announcements_path
    assert_equal "El anuncio fue eliminado.", flash[:notice]

    sign_in users(:ayudante)
    get announcements_path
    assert_response :success
    assert_select "#announcement_#{announcement.id}", count: 0
    get announcement_path(announcement)
    assert_response :not_found
  end

  test "el ayudante puede leer pero no ve ni ejecuta eliminar" do
    announcement = announcements(:one)
    sign_in users(:ayudante)

    get announcement_path(announcement)
    assert_response :success
    assert_select "button", text: "Eliminar anuncio", count: 0

    assert_no_difference "Announcement.count" do
      delete announcement_path(announcement)
    end
    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
    assert Announcement.exists?(announcement.id)
  end

  test "un alumno y un administrativo no pueden eliminar por URL directa" do
    announcement = announcements(:one)

    %i[alumno administrativo].each do |role|
      sign_in users(role)
      assert_no_difference "Announcement.count" do
        delete announcement_path(announcement)
      end
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      sign_out :user
    end
  end

  test "un profesor de otro curso de la misma universidad no puede eliminar" do
    announcement = ActsAsTenant.with_tenant(universities(:ucv)) do
      Announcement.create!(course: courses(:three), author: users(:profesor),
        subject: "Otro curso", body: "Aviso de otro curso")
    end
    sign_in users(:profesor)

    assert_no_difference "Announcement.count" do
      delete announcement_path(announcement)
    end
    assert_response :redirect
    assert Announcement.exists?(announcement.id)
  end

  test "un profesor de otra universidad no puede eliminar" do
    announcement = announcements(:one)
    sign_in users(:profesor_iusa)

    assert_no_difference "Announcement.unscoped.count" do
      delete announcement_path(announcement)
    end
    assert_response :not_found
    assert ActsAsTenant.with_tenant(universities(:ucv)) { Announcement.exists?(announcement.id) }
  end
end
