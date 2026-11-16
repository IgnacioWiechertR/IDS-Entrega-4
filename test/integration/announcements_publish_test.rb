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
    assert_redirected_to course_path(courses(:one))
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
    assert_select "#error_explanation", text: /Asunto no puede estar en blanco/
    assert_select "#error_explanation", text: /Mensaje no puede estar en blanco/
  end

  test "otros roles y visitantes no pueden publicar" do
    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for
    end
    assert_redirected_to new_user_session_path

    %i[administrativo ayudante alumno].each do |role|
      sign_in users(role)
      assert_no_difference "Announcement.count" do
        post announcements_path, params: params_for
      end
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert], "#{role} no debería publicar"
      sign_out :user
    end
  end

  test "el director no publica en la universidad que está viendo" do
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }

    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for
    end
    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  test "el coordinador publica en una sección de su asignatura que no dicta" do
    coordinator, section = coordinator_of_course_three
    sign_in coordinator

    get new_announcement_path(course_id: courses(:three).id)
    assert_select "option[value='#{section.id}']", count: 1

    assert_difference "Announcement.count", 1 do
      post announcements_path, params: params_for(course: courses(:three), section: section)
    end
    assert_redirected_to course_section_path(courses(:three), section)
    assert_equal coordinator, Announcement.order(:id).last.author
  end

  test "la cuenta de la otra sede de la misma persona no publica en esta universidad" do
    sign_in users(:profesor_iusa)

    assert_no_difference "Announcement.count" do
      post announcements_path, params: params_for
    end
    assert_response :not_found
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

  private

  # A profesor who coordinates ICC2002 without teaching it, and a section of that course.
  def coordinator_of_course_three
    ActsAsTenant.with_tenant(universities(:ucv)) do
      coordinator = User.create!(first_name: "Coordinadora", last_name: "UCV", rut: Rut.build(18_765_432),
        email: "coordinadora@ucv.test", password: "password123", role: "profesor", university: universities(:ucv))
      CourseCoordinator.create!(course: courses(:three), term: terms(:one), user: coordinator, assigned_by: users(:administrativo))
      section = Section.create!(course: courses(:three), term: terms(:one), number: 1)
      [ coordinator, section ]
    end
  end
end
