require "test_helper"
require_relative "../support/material_download_data"

class MaterialDownloadsTest < ActionDispatch::IntegrationTest
  include MaterialDownloadData

  setup { prepare_material_download_data }
  teardown { clear_material_download_files }

  test "listado y descarga exigen sesión antes de consultar el almacenamiento" do
    events = observe_download_storage do
      get course_material_downloads_path(@course)
      assert_redirected_to new_user_session_path
      get download_path
      assert_redirected_to new_user_session_path
      head download_path
      assert_redirected_to new_user_session_path
    end
    assert_empty events
  end

  test "profesor ayudante alumno y administrativo descargan el original de su curso" do
    %i[profesor ayudante alumno administrativo].each do |role|
      sign_in users(role)
      get download_path

      assert_response :success, role.to_s
      assert_equal DOWNLOAD_PDF, response.body
      assert_equal "application/octet-stream", response.media_type
      assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
      assert_includes response.headers["Content-Disposition"], 'filename="guia.pdf"'
      assert_equal DOWNLOAD_PDF.bytesize.to_s, response.headers["Content-Length"]
      assert_equal "nosniff", response.headers["X-Content-Type-Options"]
      assert_includes response.headers["Cache-Control"], "private"
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_nil response.headers["Location"]
      sign_out :user
    end
  end

  test "la sección ofrece descarga autenticada sin publicar URLs firmadas" do
    sign_in users(:alumno)
    get course_section_path(@course, @section)

    assert_response :success
    assert_select "#materials a[href=?][download][data-turbo=false]", download_path, text: "Descargar"
    assert_select "#materials a[href*='/rails/active_storage/']", count: 0
    assert_not_includes response.body, @material.file.blob.signed_id
    assert_not_includes response.body, @material.file.blob.key
  end

  test "el curso enlaza al listado de descargas disponible para coordinadores" do
    sign_in users(:profesor)
    get course_path(@course)
    assert_response :success
    assert_select "a[href=?]", course_material_downloads_path(@course), text: "Descargar material"

    get course_material_downloads_path(@course)
    assert_response :success
    assert_select "h1", "Descargar material"
    assert_select "#download_material_#{@material.id} a[href=?]", download_path, text: "Descargar"
    assert_select "#download_material_#{@foreign_material.id}", count: 0
  end

  test "el coordinador descarga aunque no dicte una sección" do
    section_staffs(:one).destroy!
    sign_in users(:profesor)

    get download_path

    assert_response :success
    assert_equal DOWNLOAD_PDF, response.body
  end

  test "una cuenta de alumno asignada como ayudante conserva la descarga" do
    enrollments(:one).destroy!
    SectionStaff.create!(section: @section, user: users(:alumno), role: "ayudante", assigned_by: users(:administrativo))
    sign_in users(:alumno)

    get download_path

    assert_response :success
    assert_equal DOWNLOAD_PDF, response.body
  end

  test "una matrícula desactivada impide reutilizar un enlace de descarga guardado" do
    sign_in users(:alumno)
    get download_path
    assert_response :success
    previous_date = response.headers["Last-Modified"]
    enrollments(:one).update!(active: false)

    events = observe_download_storage do
      get download_path, headers: { "If-Modified-Since" => previous_date }
      assert_redirected_to courses_path
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      get course_material_downloads_path(@course)
      assert_redirected_to courses_path
    end
    assert_empty events
  end

  test "retirar la docencia y la coordinación revoca la descarga del profesor" do
    sign_in users(:profesor)
    get download_path
    assert_response :success
    section_staffs(:one).destroy!
    course_coordinators(:one).destroy!

    events = observe_download_storage do
      get download_path
      assert_redirected_to courses_path
    end
    assert_empty events
  end

  test "no basta con pertenecer a la universidad si el curso es ajeno" do
    other = download_material(course: courses(:three), title: "Curso sin participación")
    %i[profesor ayudante alumno].each do |role|
      sign_in users(role)
      events = observe_download_storage do
        get course_material_download_path(courses(:three), other)
        assert_redirected_to courses_path
        get course_material_downloads_path(courses(:three))
        assert_redirected_to courses_path
      end
      assert_empty events
      sign_out :user
    end
  end

  test "ningún rol universitario descarga un curso de otra universidad por id" do
    %i[profesor ayudante alumno administrativo].each do |role|
      [ course_material_downloads_path(courses(:two)), course_material_download_path(courses(:two), @foreign_material) ].each do |path|
        sign_in users(role)
        events = observe_download_storage do
          get path
          assert_response :not_found
        end
        assert_empty events
      end
      sign_out :user
    end
  end

  test "la segunda universidad descarga sus propios archivos" do
    sign_in users(:alumno_iusa)
    get course_material_downloads_path(courses(:two))
    assert_response :success
    assert_select "a[href=?]", course_material_download_path(courses(:two), @foreign_material)
    assert_select "a[href=?]", download_path, count: 0

    get course_material_download_path(courses(:two), @foreign_material)
    assert_response :success
    assert_equal DOWNLOAD_PDF, response.body
  end

  test "el director debe seleccionar la universidad a la que pertenece el archivo" do
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }
    get download_path
    assert_response :success
    get course_material_download_path(courses(:two), @foreign_material)
    assert_response :not_found

    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:iusa).id }
    get course_material_download_path(courses(:two), @foreign_material)
    assert_response :success
    get download_path
    assert_response :not_found
  end

  test "un material no puede anidarse bajo otro curso permitido" do
    another = download_material(course: courses(:three))
    [ another, @foreign_material ].each do |material|
      sign_in users(:administrativo)
      events = observe_download_storage do
        get course_material_download_path(@course, material)
        assert_response :not_found
      end
      assert_empty events
    end
  end

  test "los parámetros no permiten sustituir el blob ni cambiar universidad o disposición" do
    sign_in users(:alumno)
    get download_path, params: { blob_id: @foreign_material.file.blob_id, signed_id: @foreign_material.file.blob.signed_id,
      university_id: universities(:iusa).id, disposition: "inline", filename: "alterado.html" }

    assert_response :success
    assert_equal DOWNLOAD_PDF, response.body
    assert_includes response.headers["Content-Disposition"], 'filename="guia.pdf"'
    assert_match(/\Aattachment;/, response.headers["Content-Disposition"])
  end

  test "la descarga no transforma el contenido de documentos de oficina o texto" do
    %w[docx xlsx pptx txt].each do |extension|
      content = extension == "txt" ? "Contenido de texto UTF-8\n123\t你好" : download_office_document(extension)
      material = download_material(filename: "documento.#{extension}", content: content)
      sign_in users(:alumno)

      get course_material_download_path(@course, material)

      assert_response :success
      assert_equal content.b, response.body.b
      assert_includes response.headers["Content-Disposition"], "documento.#{extension}"
    end
  end

  test "un nombre con acentos o caracteres de cabecera se entrega sin inyectar headers" do
    @material.file.blob.update!(filename: "Guía\r\nX-Inyectado: sí.pdf")
    sign_in users(:alumno)

    get download_path

    assert_response :success
    header = response.headers["Content-Disposition"]
    assert_includes header, "filename*=UTF-8''"
    refute_match(/[\r\n]/, header)
    assert_nil response.headers["X-Inyectado"]
    assert_equal DOWNLOAD_PDF, response.body
  end

  test "HEAD consulta metadatos sin descargar los bytes" do
    sign_in users(:alumno)
    events = observe_download_storage do
      head download_path
    end

    assert_response :success
    assert_equal "", response.body
    assert_equal DOWNLOAD_PDF.bytesize.to_s, response.headers["Content-Length"]
    assert events.none? { |event| event.name.include?("download") }
    assert events.any? { |event| event.name == "service_exist.active_storage" }
  end

  test "la descarga utiliza streaming de Active Storage y conserva los bytes" do
    sign_in users(:alumno)
    events = observe_download_storage { get download_path }

    assert_response :success
    assert_equal DOWNLOAD_PDF, response.body
    assert events.any? { |event| event.name == "service_streaming_download.active_storage" }
    assert events.none? { |event| event.name == "service_download.active_storage" }
    assert_nil response.headers["ETag"]
  end

  test "un adjunto ausente o un archivo borrado responde con un mensaje sin rutas internas" do
    sign_in users(:alumno)
    get course_material_download_path(@course, materials(:one))
    assert_response :not_found
    assert_equal "El archivo no está disponible para descargar.", response.body

    @material.file.blob.service.delete(@material.file.blob.key)
    sign_in users(:alumno)
    get download_path
    assert_response :not_found
    assert_equal "El archivo no está disponible para descargar.", response.body
    assert_not_includes response.body, @material.file.blob.key
  end

  test "sin material se informa al usuario y los registros sin archivo no ofrecen descarga" do
    sign_in users(:alumno)
    get course_material_downloads_path(@course)
    assert_response :success
    assert_select "#download_material_#{materials(:one).id}", text: /Archivo no disponible/
    assert_select "#download_material_#{materials(:one).id} a", count: 0

    @course.materials.destroy_all
    get course_material_downloads_path(@course)
    assert_response :success
    assert_select "#material_downloads_empty", text: /Este curso aún no tiene material para descargar/
  end

  private

  def download_path
    course_material_download_path(@course, @material)
  end
end
