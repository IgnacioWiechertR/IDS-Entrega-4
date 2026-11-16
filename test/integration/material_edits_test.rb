require "test_helper"
require_relative "../support/material_edit_data"

class MaterialEditsTest < ActionDispatch::IntegrationTest
  include MaterialEditData

  setup { prepare_material_edit_data }
  teardown { clear_material_edit_files }

  test "listado formulario y actualización exigen sesión" do
    get course_material_edits_path(@course)
    assert_redirected_to new_user_session_path
    get edit_path
    assert_redirected_to new_user_session_path
    assert_unchanged_original do
      patch update_path, params: { material: { title: "Sin sesión", file: edit_upload } }
      assert_redirected_to new_user_session_path
    end
  end

  test "el autor encuentra el acceso en el curso y solo su propio material en la sección" do
    sign_in @professor
    get course_path(@course)
    assert_response :success
    assert_select "a[href=?]", course_material_edits_path(@course), text: "Editar mi material"

    get course_section_path(@course, @section)
    assert_response :success
    assert_select "a[href=?]", edit_path, text: "Editar"
    assert_select "a[href=?]", edit_course_material_edit_path(@course, @peer_material), count: 0

    get course_material_edits_path(@course)
    assert_response :success
    assert_select "#editable_material_#{@owned.id} a[href=?]", edit_path
    assert_select "#editable_material_#{@peer_material.id}", count: 0
    assert_select "#editable_material_#{materials(:one).id}", count: 0
    assert_select "#editable_material_#{@foreign.id}", count: 0
  end

  test "el formulario muestra título y archivo opcional sin permitir cambiar curso ni autor" do
    sign_in @professor
    get edit_path

    assert_response :success
    assert_select "form[action=?][enctype='multipart/form-data']", update_path
    assert_select "input[name='material[title]'][value=?]", @owned.title
    assert_select "input[type=file][accept*='.pdf'][accept*='.docx'][accept*='.xlsx'][accept*='.pptx']"
    assert_select "input[type=file][required]", count: 0
    assert_select "#current_material_file", text: /original\.pdf/
    assert_select "#material_edit_file_help", text: /Máximo 50 MB/
    assert_select "input[name='material[course_id]'], input[name='material[uploaded_by_id]']", count: 0
  end

  test "editar solo el título conserva autor blob nombre bytes y servicio" do
    old_blob = @owned.file.blob
    sign_in @professor

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      patch update_path, params: { material: { title: "Título corregido", file: "" } }
    end

    assert_response :see_other
    assert_redirected_to edit_path
    @owned.reload
    assert_equal "Título corregido", @owned.title
    assert_equal @professor.id, @owned.uploaded_by_id
    assert_equal old_blob.id, @owned.file.blob_id
    assert_equal old_blob.filename, @owned.file.filename
    assert_equal old_blob.service_name, @owned.file.blob.service_name
    assert_equal EDIT_PDF, @owned.file.download
    follow_redirect!
    assert_select "[role=status]", text: /Material actualizado correctamente/
  end

  test "reemplaza el archivo y conserva el material y su autor" do
    old_blob = @owned.file.blob
    sign_in @professor

    assert_no_difference "Material.count" do
      assert_difference "ActiveStorage::Blob.count", 1 do
        assert_no_difference "ActiveStorage::Attachment.count" do
          patch update_path, params: { material: { title: "Guía actualizada", file: edit_upload } }
        end
      end
    end

    assert_response :see_other
    @owned.reload
    assert_equal "Guía actualizada", @owned.title
    assert_equal @professor.id, @owned.uploaded_by_id
    assert_not_equal old_blob.id, @owned.file.blob_id
    assert_equal "actualizado.pdf", @owned.file.filename.to_s
    assert_equal REPLACEMENT_PDF, @owned.file.download
    assert_equal "test", @owned.file.blob.service_name
  end

  test "se puede reemplazar solo el archivo conservando el título" do
    sign_in @professor
    patch update_path, params: { material: { file: edit_upload } }

    assert_response :see_other
    assert_equal "Material propio", @owned.reload.title
    assert_equal REPLACEMENT_PDF, @owned.file.download
  end

  test "un título vacío con reemplazo no cambia el material ni crea adjuntos" do
    sign_in @professor
    assert_unchanged_original do
      patch update_path, params: { material: { title: " ", file: edit_upload } }
      assert_response :unprocessable_content
      assert_select "[role=alert]", text: /Título/
      assert_select "#current_material_file", text: /original\.pdf/
    end
  end

  test "un archivo vacío con título nuevo conserva el título y archivo anteriores" do
    sign_in @professor
    assert_unchanged_original do
      patch update_path, params: { material: { title: "No guardar", file: edit_upload(content: "") } }
      assert_response :unprocessable_content
      assert_select "[role=alert]", text: /vacío/
      assert_select "input[name='material[title]'][value=?]", "No guardar"
    end
  end

  test "rechaza extensiones no admitidas y archivos renombrados conservando el original" do
    sign_in @professor
    [ edit_upload(filename: "programa.exe"), edit_upload(content: "<html>No es PDF</html>") ].each do |upload|
      assert_unchanged_original do
        patch update_path, params: { material: { title: "No guardar", file: upload } }
        assert_response :unprocessable_content
        assert_select "[role=alert]", text: /formato no permitido/
      end
    end
  end

  test "rechaza un archivo mayor de 50 MB sin reemplazar el original" do
    sign_in @professor
    Tempfile.create([ "material-b3", ".pdf" ]) do |file|
      file.binmode
      file.write(REPLACEMENT_PDF)
      file.truncate(50_000_001)
      file.rewind
      upload = Rack::Test::UploadedFile.new(file.path, "application/pdf", true, original_filename: "grande.pdf")
      begin
        assert_unchanged_original do
          patch update_path, params: { material: { title: "No guardar", file: upload } }
          assert_response :unprocessable_content
          assert_select "[role=alert]", text: /no puede superar 50 MB/
        end
      ensure
        upload.tempfile.close!
      end
    end
  end

  test "no acepta signed IDs ni blobs existentes de su universidad o de otra" do
    sign_in @professor
    [ @peer_material.file.blob.signed_id, @foreign.file.blob.signed_id ].each do |signed_id|
      assert_unchanged_original do
        patch update_path, params: { material: { title: "No guardar", file: signed_id } }
        assert_response :unprocessable_content
        assert_select "[role=alert]", text: /desde tu equipo/
      end
    end
  end

  test "ignora intentos de cambiar propietario curso universidad o eliminar el archivo" do
    sign_in @professor
    patch update_path, params: { material: { title: "Título válido", uploaded_by_id: @peer.id,
      course_id: courses(:three).id, university_id: universities(:iusa).id, remove_file: "1", _destroy: "1" } }

    assert_response :see_other
    @owned.reload
    assert_equal "Título válido", @owned.title
    assert_equal @professor.id, @owned.uploaded_by_id
    assert_equal @course.id, @owned.course_id
    assert_equal EDIT_PDF, @owned.file.download
  end

  test "otro profesor del mismo curso no puede editar ni asumir la autoría" do
    sign_in @peer
    get edit_path
    assert_redirected_to courses_path

    assert_unchanged_original do
      patch update_path, params: { material: { title: "Ajeno", uploaded_by_id: @peer.id, file: edit_upload } }
      assert_redirected_to courses_path
    end

    get course_material_edits_path(@course)
    assert_response :success
    assert_select "#editable_material_#{@owned.id}", count: 0
    assert_select "#editable_material_#{@peer_material.id}"
  end

  test "ser coordinador no permite editar material subido por otro profesor" do
    sign_in @professor
    get edit_course_material_edit_path(@course, @peer_material)
    assert_redirected_to courses_path

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      patch course_material_edit_path(@course, @peer_material), params: { material: { title: "Otro", file: edit_upload } }
    end
    assert_redirected_to courses_path
    assert_equal "Material de otro profesor", @peer_material.reload.title
  end

  test "director administrativo ayudante y alumno no editan aunque puedan leer el curso" do
    %i[director administrativo ayudante alumno].each do |role|
      sign_in users(role)
      patch university_selection_path, params: { university_id: @course.university_id } if role == :director
      get edit_path
      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      assert_unchanged_original do
        patch update_path, params: { material: { title: "No autorizado", file: edit_upload } }
        assert_response :redirect
        assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      end
      get course_material_edits_path(@course)
      assert_response :redirect
      sign_out :user
    end
  end

  test "el autor coordinador puede editar aunque no dicte una sección" do
    section_staffs(:one).destroy!
    sign_in @professor
    patch update_path, params: { material: { title: "Por su autor coordinador" } }

    assert_response :see_other
    assert_equal "Por su autor coordinador", @owned.reload.title
  end

  test "retirar toda participación o cambiar el rol revoca la edición del autor" do
    section_staffs(:one).destroy!
    course_coordinators(:one).destroy!
    sign_in @professor

    assert_unchanged_original do
      patch update_path, params: { material: { title: "Sin participación" } }
      assert_redirected_to courses_path
    end

    @professor.update!(role: "administrativo")
    sign_in @professor
    assert_unchanged_original do
      patch update_path, params: { material: { title: "Ya no es profesor" } }
      assert_redirected_to accounts_path
    end
  end

  test "los materiales anteriores sin autor identificado no pueden editarse" do
    sign_in @professor
    get edit_course_material_edit_path(@course, materials(:one))
    assert_redirected_to courses_path

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      patch course_material_edit_path(@course, materials(:one)), params: { material: { title: "Atribución inventada", uploaded_by_id: @professor.id } }
    end
    assert_redirected_to courses_path
    assert_nil materials(:one).reload.uploaded_by_id
  end

  test "otra universidad no puede abrir ni modificar por ID" do
    [ :get, :patch ].each do |verb|
      sign_in @professor
      assert_unchanged_original do
        if verb == :get
          get edit_course_material_edit_path(courses(:two), @foreign)
        else
          patch course_material_edit_path(courses(:two), @foreign), params: { material: { title: "Intruso", file: edit_upload } }
        end
        assert_response :not_found
      end
    end
  end

  test "la segunda universidad edita su propio material" do
    sign_in users(:profesor_iusa)
    patch course_material_edit_path(courses(:two), @foreign), params: { material: { title: "Título IUSA", file: edit_upload } }

    assert_response :see_other
    assert_equal "Título IUSA", @foreign.reload.title
    assert_equal users(:profesor_iusa).id, @foreign.uploaded_by_id
    assert_equal REPLACEMENT_PDF, @foreign.file.download
  end

  test "un material no puede colocarse en la URL de otro curso" do
    sign_in @professor
    get edit_course_material_edit_path(@course, @foreign)
    assert_response :not_found
  end

  test "las rutas globales del scaffold no abren otra vía de edición o eliminación" do
    [ [ :get, "/materials/#{@owned.id}/edit" ], [ :patch, "/materials/#{@owned.id}" ], [ :delete, "/materials/#{@owned.id}" ] ].each do |verb, path|
      sign_in @professor
      assert_unchanged_original do
        public_send(verb, path, params: { material: { title: "Scaffold" } })
        assert_response :not_found
      end
    end
  end

  private

  def edit_path
    edit_course_material_edit_path(@course, @owned)
  end

  def update_path
    course_material_edit_path(@course, @owned)
  end

  def assert_unchanged_original
    blob_id = @owned.file.blob_id
    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      yield
    end
    @owned.reload
    assert_equal "Material propio", @owned.title
    assert_equal @professor.id, @owned.uploaded_by_id
    assert_equal blob_id, @owned.file.blob_id
    assert_equal EDIT_PDF, @owned.file.download
  end
end
