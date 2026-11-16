require "test_helper"

class AnnouncementsPublishTest < ActionDispatch::IntegrationTest
  def params_for(course: courses(:one), section: nil, subject: "Cambio de sala", body: "La clase será en otra sala.")
    { announcement: { course_id: course.id, section_id: section&.id, subject: subject, body: body } }
  end

  test "el profesor publica para toda su asignatura y el autor se toma de la sesión" do
    sign_in users(:profesor)
    get new_announcement_path(course_id: courses(:one).id)
    assert_response :success
    assert_select "option[value='']", text: "Toda la asignatura"
    assert_select "option[value='#{sections(:one).id}']", count: 1

    assert_difference "Announcement.count", 1 do
      post announcements_path, params: params_for.merge(announcement: params_for[:announcement].merge(author_id: users(:administrativo).id))
    end
    assert_response :see_other
    announcement = Announcement.order(:id).last
    assert_equal users(:profesor), announcement.author
    assert_nil announcement.section
    assert_equal courses(:one).id, announcement.course_id
    assert announcement.created_at.present?
  end

  test "el profesor publica para su sección" do
    sign_in users(:profesor)
    assert_difference "Announcement.count", 1 do
      post announcements_path, params: params_for(section: sections(:one))
    end
    assert_equal sections(:one).id, Announcement.order(:id).last.section_id
    assert_redirected_to course_section_path(courses(:one), sections(:one))
  end

  test "el enlace aparece en la sección del profesor" do
    sign_in users(:profesor)
    get course_section_path(courses(:one), sections(:one))
    assert_select "a[href=?]", new_announcement_path(course_id: courses(:one).id, section_id: sections(:one).id),
      text: "Publicar anuncio"
  end

  test "asunto y cuerpo son obligatorios" do
    sign_in users(:profesor)
    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for(subject: " ", body: " ")
    end
    assert_response :unprocessable_content
    assert_select "#error_explanation", text: /Asunto|Subject/
  end

  test "otros roles y visitantes no pueden publicar" do
    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for
    end
    assert_redirected_to new_user_session_path

    %i[administrativo ayudante alumno director].each do |role|
      sign_in users(role)
      assert_no_difference "Announcement.count" do
        post announcements_path, params: params_for
      end
      assert_includes [ 302, 404 ], response.status
      sign_out :user
    end
  end

  test "rechaza cursos y secciones ajenos incluso con IDs enviados directamente" do
    sign_in users(:profesor)
    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for(course: courses(:two))
    end
    assert_response :not_found

    sign_in users(:profesor)
    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for(course: courses(:three))
    end
    assert_response :redirect

    sign_in users(:profesor)
    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for(section: sections(:two))
    end
    assert_response :not_found
  end
end
