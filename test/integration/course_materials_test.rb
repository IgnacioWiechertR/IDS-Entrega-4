require "test_helper"
require_relative "../support/material_read_data"

class CourseMaterialsTest < ActionDispatch::IntegrationTest
  include MaterialReadData

  setup { prepare_material_read_data }
  teardown { clear_material_read_files }

  test "listado detalle y vista previa exigen iniciar sesión" do
    material_read_paths.each do |path|
      get path
      assert_redirected_to new_user_session_path
    end
  end

  test "profesor ayudante alumno y administrativo consultan el material del curso" do
    %i[profesor ayudante alumno administrativo].each do |role|
      sign_in users(role)
      get course_materials_path(@course)
      assert_response :success, role.to_s
      assert_select "h1", "Material del curso"
      assert_select "#material_#{@material.id} a[href=?]", course_material_path(@course, @material), text: @material.title
      assert_select "#material_#{@foreign_material.id}", count: 0

      get course_material_path(@course, @material)
      assert_response :success
      assert_select "h1", @material.title
      assert_select "#material_details", text: /guia\.pdf/
      assert_select "iframe[src=?][title]", preview_course_material_path(@course, @material)
      sign_out :user
    end
  end

  test "el listado muestra primero el material más reciente con desempate por id" do
    older = read_material(title: "Guía anterior", created_at: 2.days.ago)
    newer = read_material(title: "Guía reciente", created_at: 1.day.ago)
    tied = read_material(title: "Guía del mismo momento", created_at: newer.created_at)
    sign_in users(:alumno)

    get course_materials_path(@course)

    assert_response :success
    assert_operator response.body.index(@material.title), :<, response.body.index(tied.title)
    assert_operator response.body.index(tied.title), :<, response.body.index(newer.title)
    assert_operator response.body.index(newer.title), :<, response.body.index(older.title)
  end

  test "el alumno encuentra el material en su sección sin enlaces públicos al archivo" do
    sign_in users(:alumno)
    get course_section_path(@course, @section)

    assert_response :success
    assert_select "#materials a[href=?]", course_material_path(@course, @material)
    assert_select "a[href=?]", course_materials_path(@course), text: "Ver todo el material"
    assert_select "#materials a[href*='/rails/active_storage/']", count: 0
  end

  test "administrativo y coordinador encuentran el material en la vista del curso" do
    %i[administrativo profesor].each do |role|
      sign_in users(role)
      get course_path(@course)
      assert_response :success
      assert_select "#materials a[href=?]", course_material_path(@course, @material)
      sign_out :user
    end
  end

  test "un profesor que solo coordina puede ver el material sin dictar secciones" do
    ActsAsTenant.with_tenant(universities(:ucv)) { section_staffs(:one).destroy! }
    sign_in users(:profesor)

    material_read_paths.each do |path|
      get path
      assert_response :success
    end
  end

  test "un ayudante con cuenta de alumno puede consultar el material de su curso" do
    ActsAsTenant.with_tenant(universities(:ucv)) do
      enrollments(:one).destroy!
      SectionStaff.create!(section: @section, user: users(:alumno), role: "ayudante", assigned_by: users(:administrativo))
    end
    sign_in users(:alumno)

    material_read_paths.each do |path|
      get path
      assert_response :success
    end
  end

  test "una matrícula inactiva no da acceso al listado detalle ni bytes" do
    ActsAsTenant.with_tenant(universities(:ucv)) { enrollments(:one).update!(active: false) }
    sign_in users(:alumno)

    material_read_paths.each do |path|
      get path
      assert_redirected_to courses_path
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      assert_not_includes response.body, "%PDF-"
    end
  end

  test "no basta con pertenecer a la universidad para consultar un curso ajeno" do
    hidden = read_material(course: courses(:three), title: "Guía de otro curso")
    %i[profesor ayudante alumno].each do |role|
      sign_in users(role)
      material_read_paths(course: courses(:three), material: hidden).each do |path|
        get path
        assert_redirected_to courses_path
        assert_not_includes response.body, hidden.title
      end
      sign_out :user
    end
  end

  test "las rutas no permiten consultar otra universidad por id" do
    %i[profesor ayudante alumno administrativo].each do |role|
      sign_in users(role)
      material_read_paths(course: courses(:two), material: @foreign_material).each do |path|
        sign_in users(role)
        get path
        assert_response :not_found
        assert_not_includes response.body, @foreign_material.title
      end
      sign_out :user
    end
  end

  test "la segunda universidad consulta su propio material" do
    sign_in users(:alumno_iusa)
    get course_materials_path(courses(:two))
    assert_response :success
    assert_select "#material_#{@foreign_material.id}"
    assert_select "#material_#{@material.id}", count: 0

    get preview_course_material_path(courses(:two), @foreign_material)
    assert_response :success
    assert_equal read_pdf_bytes, response.body
  end

  test "el director consulta solo la universidad activa y debe cambiarla para ver la otra" do
    sign_in users(:director)
    patch university_selection_path, params: { university_id: universities(:ucv).id }
    material_read_paths.each do |path|
      get path
      assert_response :success
    end
    get preview_course_material_path(courses(:two), @foreign_material)
    assert_response :not_found

    patch university_selection_path, params: { university_id: universities(:iusa).id }
    material_read_paths(course: courses(:two), material: @foreign_material).each do |path|
      get path
      assert_response :success
    end
    get preview_course_material_path(@course, @material)
    assert_response :not_found
  end

  test "un material de otro curso no se puede obtener anidándolo bajo un curso permitido" do
    hidden = read_material(course: courses(:three), title: "Material ajeno")
    sign_in users(:administrativo)

    [ hidden, @foreign_material ].each do |material|
      sign_in users(:administrativo)
      get course_material_path(@course, material)
      assert_response :not_found
      sign_in users(:administrativo)
      get preview_course_material_path(@course, material)
      assert_response :not_found
    end
  end

  test "la vista previa PDF entrega contenido inline privado sin redirigir al bucket" do
    sign_in users(:alumno)
    get preview_course_material_path(@course, @material)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_equal read_pdf_bytes, response.body
    assert_match(/\Ainline;/, response.headers["Content-Disposition"])
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Cache-Control"], "private"
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_nil response.headers["Location"]
  end

  test "la vista previa de texto escapa HTML y conserva saltos de línea" do
    text = read_material(filename: "guia.txt", content: "Primera línea\n<script>alert('x')</script>")
    sign_in users(:alumno)

    get preview_course_material_path(@course, text)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "#text_preview", text: "Primera línea\n<script>alert('x')</script>"
    assert_select "script", count: 0
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "el texto extenso informa que se muestra solo el comienzo" do
    text = read_material(filename: "apuntes.md", content: "A" * 256_100)
    sign_in users(:alumno)
    get preview_course_material_path(@course, text)

    assert_response :success
    assert_select "[role=status]", text: /primeros 256 KB/
    assert_select "#text_preview", text: "A" * 256_000
  end

  test "los cursos sin material muestran un mensaje" do
    @course.materials.destroy_all
    sign_in users(:alumno)

    get course_materials_path(@course)

    assert_response :success
    assert_select "#materials_empty", "Este curso aún no tiene material."
  end

  test "los registros sin adjunto muestran detalle sin intentar generar vista previa" do
    material = materials(:one)
    sign_in users(:alumno)
    get course_material_path(@course, material)

    assert_response :success
    assert_select "#material_details", text: /Archivo no disponible/
    assert_select "iframe", count: 0
    get preview_course_material_path(@course, material)
    assert_response :unprocessable_content
    assert_select "[role=status]", text: /No se pudo generar/
  end

  test "los errores de almacenamiento no muestran rutas internas ni fallan con error 500" do
    @material.file.blob.service.delete(@material.file.blob.key)
    sign_in users(:alumno)

    get preview_course_material_path(@course, @material)

    assert_response :unprocessable_content
    assert_select "[role=status]", text: /No se pudo generar/
    assert_not_includes response.body, @material.file.blob.key
  end

  test "rechaza un PDF cuyo contenido es HTML aunque tenga extensión y MIME de PDF" do
    fake = read_material(filename: "falso.pdf", content: "<html><script>alert('x')</script></html>")
    sign_in users(:alumno)

    get preview_course_material_path(@course, fake)

    assert_response :unprocessable_content
    assert_select "script", count: 0
  end

  test "ver material no permite modificarlo y no publica signed ids en las páginas" do
    sign_in users(:alumno)

    [ course_materials_path(@course), course_material_path(@course, @material) ].each do |path|
      get path
      assert_response :success
      assert_select "main form", count: 0
      assert_select "main a", text: /Editar|Eliminar|Descargar/, count: 0
      assert_not_includes response.body, @material.file.blob.signed_id
    end

    assert_no_difference "Material.count" do
      patch "/materials/#{@material.id}", params: { material: { title: "Alterado" } }
      assert_global_material_route_closed
      sign_in users(:alumno)
      delete "/materials/#{@material.id}"
      assert_global_material_route_closed
    end
    assert_equal "Guía de programación", @material.reload.title
  end

  test "el visor informa un formato de oficina dañado sin servir sus bytes como HTML" do
    invalid = read_material(filename: "documento.docx", content: "<html><script>alert('x')</script></html>")
    sign_in users(:alumno)

    get preview_course_material_path(@course, invalid)

    assert_response :unprocessable_content
    assert_select "[role=status]", text: /No se pudo generar/
    assert_select "script", count: 0
  end

  private

  # Other cards remove the scaffold routes; while present, they must deny access.
  def assert_global_material_route_closed
    if response.redirect?
      assert_redirected_to courses_path
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
    else
      assert_response :not_found
    end
  end

  def material_read_paths(course: @course, material: @material)
    [ course_materials_path(course), course_material_path(course, material), preview_course_material_path(course, material) ]
  end
end
