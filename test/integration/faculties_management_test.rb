require "test_helper"

# Faculties of a university: the administrativo creates, edits and deletes those of its own university (every
# course needs one). The director only lists them; nobody else reaches them.
class FacultiesManagementTest < ActionDispatch::IntegrationTest
  setup do
    @faculty = faculties(:one) # UCV, Facultad de Ingeniería, with courses
  end

  test "el administrativo crea, edita y lista las facultades de su universidad" do
    sign_in users(:administrativo)
    get faculties_path
    assert_select "#faculties", text: /Facultad de Ingeniería/
    assert_select "#faculties", text: /Ciencias de la Salud/, count: 0

    assert_difference "Faculty.count", 1 do
      post faculties_path, params: { faculty: { name: "  Facultad de   Derecho ", university_id: universities(:iusa).id } }
    end
    assert_redirected_to faculties_path
    created = Faculty.find_by!(name: "Facultad de Derecho")
    assert_equal universities(:ucv), created.university

    patch faculty_path(created), params: { faculty: { name: "Facultad de Derecho y Ciencias Sociales" } }
    assert_redirected_to faculties_path
    assert_equal "Facultad de Derecho y Ciencias Sociales", created.reload.name
  end

  test "rechaza un nombre vacío o repetido en la misma universidad" do
    sign_in users(:administrativo)

    [ "", "facultad de ingeniería" ].each do |name|
      assert_no_difference "Faculty.count", name do
        post faculties_path, params: { faculty: { name: name } }
      end
      assert_response :unprocessable_content
      assert_select "#error_explanation", text: /Nombre/
    end
  end

  test "el mismo nombre puede existir en la otra universidad" do
    sign_in users(:administrativo)

    assert_difference "Faculty.count", 1 do
      post faculties_path, params: { faculty: { name: "Facultad de Ciencias de la Salud" } }
    end
  end

  test "no se elimina una facultad con cursos, y sus cursos siguen intactos" do
    sign_in users(:administrativo)

    assert_no_difference [ "Faculty.count", "Course.count" ] do
      delete faculty_path(@faculty)
    end
    follow_redirect!
    assert_select "body", text: /No se puede eliminar la facultad Facultad de Ingeniería porque tiene cursos/

    empty = Faculty.create!(university: universities(:ucv), name: "Facultad sin cursos")
    assert_difference "Faculty.count", -1 do
      delete faculty_path(empty)
    end
  end

  test "una facultad de la otra universidad no se ve ni se modifica" do
    sign_in users(:administrativo)

    get edit_faculty_path(faculties(:two))
    assert_response :not_found

    # A 404 does not keep the test session (Devise test helpers), so it signs in again.
    sign_in users(:administrativo)
    assert_no_difference "ActsAsTenant.without_tenant { Faculty.count }" do
      delete faculty_path(faculties(:two))
    end
    assert_response :not_found
  end

  test "el director ve las facultades sin modificarlas, y el resto de los roles no entra" do
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }
    get faculties_path
    assert_response :success
    assert_select "a", text: "Nueva facultad", count: 0
    assert_no_difference "Faculty.count" do
      post faculties_path, params: { faculty: { name: "Facultad nueva" } }
    end
    sign_out :user

    %i[profesor ayudante alumno].each do |role|
      sign_in users(role)
      get faculties_path
      assert_response :redirect, role.to_s
      sign_out :user
    end
  end

  # The client receives an empty university: everything must be creatable from the app, in order.
  test "con una universidad vacía el administrativo arma facultad, curso, período y sección" do
    university = admin = nil
    ActsAsTenant.without_tenant do
      university = University.create!(name: "Universidad Nueva", slug: "nueva")
      admin = User.create!(first_name: "Admin", last_name: "Nueva", rut: "12345678-5", email: "admin@nueva.test",
        role: "administrativo", university: university, password: "password123")
    end
    sign_in admin

    get new_course_path
    assert_select "#no_faculties a[href=?]", new_faculty_path
    post faculties_path, params: { faculty: { name: "Facultad de Ingeniería" } }
    faculty = ActsAsTenant.with_tenant(university) { Faculty.sole }

    post courses_path, params: { course: { code: "ING101", name: "Introducción", faculty_id: faculty.id } }
    course = ActsAsTenant.with_tenant(university) { Course.sole }

    get new_course_section_path(course)
    assert_select "#no_terms a[href=?]", new_term_path
    post terms_path, params: { term: { name: "2027-1", starts_on: "2027-03-01", ends_on: "2027-07-16", current: "1" } }
    term = ActsAsTenant.with_tenant(university) { Term.sole }
    assert term.current

    get new_course_section_path(course)
    assert_select "#no_terms", count: 0
    assert_difference -> { ActsAsTenant.with_tenant(university) { Section.count } }, 1 do
      post course_sections_path(course), params: { section: { term_id: term.id, number: 1 } }
    end
  end
end
