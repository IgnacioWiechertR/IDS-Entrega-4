require "test_helper"
require "stringio"

# Syllabus per course and term (Entregas 2 y 3): only uploaded as a file, by the administrativo or the coordinator
# of the course in that term, and viewed in the page or downloaded by everyone who can read the course.
class SyllabiTest < ActionDispatch::IntegrationTest
  PDF = "%PDF-1.4\nSyllabus de prueba\n%%EOF\n".freeze

  setup do
    @initial_blob_keys = ActiveStorage::Blob.pluck(:key)
    @course = courses(:one)
    @term = terms(:one)
    @section = sections(:one)
  end

  teardown do
    ActiveStorage::Blob.where.not(key: @initial_blob_keys).find_each do |blob|
      blob.service.delete(blob.key) if blob.service.is_a?(ActiveStorage::Service::DiskService)
    end
  end

  test "sin sesión no se ve ni se sube" do
    get course_syllabus_path(@course, term_id: @term.id)
    assert_redirected_to new_user_session_path

    get new_course_syllabus_path(@course, term_id: @term.id)
    assert_redirected_to new_user_session_path
  end

  test "el administrativo sube el syllabus del período y queda en el curso" do
    sign_in users(:administrativo)

    get new_course_syllabus_path(@course, term_id: @term.id)
    assert_response :success
    assert_select "h1", "Subir syllabus"

    assert_difference "Syllabus.count", 1 do
      upload_syllabus
    end
    assert_redirected_to course_syllabus_path(@course, term_id: @term.id)
    follow_redirect!
    assert_select "body", text: /El syllabus fue subido/

    syllabus = Syllabus.last
    assert_equal [ @course, @term, users(:administrativo) ], [ syllabus.course, syllabus.term, syllabus.uploaded_by ]
    assert_equal @course.university_id, syllabus.university_id

    get course_path(@course, term_id: @term.id)
    assert_select "#syllabus", text: /programa\.pdf/
    assert_select "#syllabus a[href=?]", course_syllabus_path(@course, term_id: @term.id), text: "Ver syllabus"
    assert_select "#syllabus a[href=?]", download_course_syllabus_path(@course, term_id: @term.id), text: "Descargar"
    # The term already began: it was the first upload, so it is allowed, but from now on it stays as it is.
    assert_select "#syllabus a", text: "Reemplazar syllabus", count: 0
  end

  test "antes de que empiece el período el coordinador lo sube y lo reemplaza sin duplicarlo" do
    term = upcoming_term_coordinated_by(users(:profesor))
    sign_in users(:profesor)
    upload_syllabus(filename: "v1.pdf", term: term)
    assert_equal "v1.pdf", Syllabus.find_by!(course: @course, term: term).file.filename.to_s

    assert_no_difference "Syllabus.count" do
      upload_syllabus(filename: "v2.pdf", term: term)
    end
    follow_redirect!
    assert_select "body", text: /El syllabus fue reemplazado/
    assert_equal "v2.pdf", Syllabus.find_by!(course: @course, term: term).file.filename.to_s
  end

  test "desde que empieza el período nadie lo reemplaza" do
    create_syllabus
    assert @term.started?

    %i[administrativo profesor].each do |role|
      sign_in users(role)

      get course_syllabus_path(@course, term_id: @term.id)
      assert_select "#syllabus_locked", text: /ya comenzó/
      assert_select "a", text: "Reemplazar syllabus", count: 0
      get course_path(@course, term_id: @term.id)
      assert_select "#syllabus", text: /queda fijo/
      assert_select "#syllabus a", text: "Reemplazar syllabus", count: 0

      get new_course_syllabus_path(@course, term_id: @term.id)
      assert_redirected_to course_syllabus_path(@course, term_id: @term.id)
      assert_no_difference "ActiveStorage::Attachment.count" do
        upload_syllabus(filename: "otro.pdf")
      end
      assert_redirected_to course_syllabus_path(@course, term_id: @term.id)
      follow_redirect!
      assert_select "body", text: /no se puede reemplazar porque el período/
      assert_equal "programa.pdf", Syllabus.find_by!(course: @course, term: @term).file.filename.to_s
      sign_out :user
    end
  end

  test "el modelo tampoco acepta otro archivo una vez comenzado el período" do
    syllabus = create_syllabus
    syllabus.file = { io: StringIO.new(PDF), filename: "otro.pdf" }

    assert_not syllabus.save
    assert_includes syllabus.errors.full_messages, "Archivo no se puede reemplazar porque el período ya comenzó"
  end

  test "un profesor que no coordina el curso, el ayudante, el alumno y el director no lo suben" do
    course_coordinators(:one).destroy!

    %i[profesor ayudante alumno director].each do |role|
      sign_in_to_ucv(role)

      get new_course_syllabus_path(@course, term_id: @term.id)
      assert_response :redirect, role.to_s
      assert_no_difference "Syllabus.count", role.to_s do
        upload_syllabus
      end
      assert_response :redirect, role.to_s
      sign_out :user
    end
  end

  test "el coordinador de otro período no lo sube" do
    other_term = Term.create!(university: universities(:ucv), name: "Primer semestre 2026",
      starts_on: Date.new(2026, 3, 2), ends_on: Date.new(2026, 7, 10))
    sign_in users(:profesor)

    assert_no_difference "Syllabus.count" do
      upload_syllabus(term: other_term)
    end
    assert_response :redirect
  end

  test "solo acepta PDF válidos" do
    sign_in users(:administrativo)

    [ upload_file(filename: "programa.docx"), upload_file(filename: "falso.pdf", content: "<html>no es pdf</html>"),
      upload_file(content: "") ].each do |file|
      assert_no_difference "Syllabus.count" do
        post course_syllabus_path(@course), params: { syllabus: { term_id: @term.id, file: file } }
      end
      assert_response :unprocessable_content
      assert_select "[role=alert]", text: /Archivo/
    end

    post course_syllabus_path(@course), params: { syllabus: { term_id: @term.id } }
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /debe seleccionarse/
  end

  test "profesor ayudante alumno administrativo y director descargan el original" do
    create_syllabus

    %i[profesor ayudante alumno administrativo director].each do |role|
      sign_in_to_ucv(role)
      get download_course_syllabus_path(@course, term_id: @term.id)

      assert_response :success, role.to_s
      assert_equal "application/octet-stream", response.media_type
      assert_equal PDF, response.body
      assert_includes response.headers["Content-Disposition"], 'filename="programa.pdf"'
      assert_includes response.headers["Cache-Control"], "no-store"
      sign_out :user
    end
  end

  test "el syllabus se ve dentro de la página con el PDF en línea" do
    create_syllabus
    sign_in users(:alumno)

    get course_syllabus_path(@course, term_id: @term.id)
    assert_response :success
    assert_select "h1", text: /Syllabus · #{@course.name}/
    assert_select "iframe#syllabus_preview[src=?]", preview_course_syllabus_path(@course, term_id: @term.id)
    assert_select "a[href=?]", download_course_syllabus_path(@course, term_id: @term.id), text: "Descargar"
    assert_select "a", text: "Reemplazar syllabus", count: 0

    get preview_course_syllabus_path(@course, term_id: @term.id)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match(/\Ainline;/, response.headers["Content-Disposition"])
    assert_equal PDF, response.body
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "la sección muestra el syllabus a sus alumnos sin opción de subirlo" do
    create_syllabus
    sign_in users(:alumno)
    get course_section_path(@course, @section)

    assert_response :success
    assert_select "#syllabus a[href=?]", course_syllabus_path(@course, term_id: @term.id), text: "Ver syllabus"
    assert_select "#syllabus a", text: /Subir syllabus|Reemplazar syllabus/, count: 0
    assert_select "a[href*='/rails/active_storage/']", count: 0
  end

  test "sin syllabus el curso lo indica y ofrece subirlo a quien puede" do
    sign_in users(:administrativo)
    get course_path(@course, term_id: @term.id)

    assert_select "#syllabus", text: /todavía no tiene syllabus/
    assert_select "#syllabus a", text: "Subir syllabus"

    %i[course_syllabus_path preview_course_syllabus_path download_course_syllabus_path].each do |path|
      get public_send(path, @course, term_id: @term.id)
      assert_response :not_found, path.to_s
    end
  end

  test "otra universidad no ve ni sube el syllabus" do
    create_syllabus

    sign_in users(:administrativo_iusa)
    get course_syllabus_path(@course, term_id: @term.id)
    assert_response :not_found

    sign_in users(:administrativo_iusa)
    assert_no_difference "Syllabus.count" do
      upload_syllabus
    end
    assert_response :not_found
  end

  private

  # The director works in the university picked with the selector (A3); by default it is not UCV.
  def sign_in_to_ucv(role)
    sign_in users(role)
    patch university_selection_path, params: { university_id: universities(:ucv).id } if role == :director
  end

  def upload_file(filename: "programa.pdf", content: PDF)
    Rack::Test::UploadedFile.new(StringIO.new(content), "application/pdf", original_filename: filename)
  end

  def upload_syllabus(filename: "programa.pdf", term: @term)
    post course_syllabus_path(@course), params: { syllabus: { term_id: term.id, file: upload_file(filename: filename) } }
  end

  def upcoming_term_coordinated_by(user)
    term = Term.create!(university: universities(:ucv), name: "Primer semestre 2027",
      starts_on: Date.current + 3.months, ends_on: Date.current + 7.months)
    CourseCoordinator.create!(course: @course, term: term, user: user, assigned_by: users(:administrativo))
    term
  end

  def create_syllabus
    Syllabus.create!(course: @course, term: @term, uploaded_by: users(:administrativo),
      file: { io: StringIO.new(PDF), filename: "programa.pdf" })
  end
end
