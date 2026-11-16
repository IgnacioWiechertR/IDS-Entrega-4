require "test_helper"
require_relative "../support/material_upload_data"

class MaterialUploadsTest < ActionDispatch::IntegrationTest
  include MaterialUploadData

  setup { prepare_material_upload_data }
  teardown { clear_uploaded_test_files }

  test "la subida exige iniciar sesión" do
    get new_course_material_path(@course)
    assert_redirected_to new_user_session_path

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count" ] do
      post course_materials_path(@course), params: upload_params
    end
    assert_redirected_to new_user_session_path
  end

  test "el profesor encuentra el acceso en su sección y el formulario está vinculado al curso" do
    login_for_upload(@professor)
    get course_section_path(@course, @section)
    assert_response :success
    assert_select "a[href=?]", new_course_material_path(@course), text: "Subir material"

    get new_course_material_path(@course)
    assert_response :success
    assert_select "h1", "Subir material"
    assert_select "form[action=?][enctype='multipart/form-data']", course_materials_path(@course)
    assert_select "input[type=file][name='material[file]']"
    assert_select "input[name='material[course_id]']", count: 0
  end

  test "guarda el material y los bytes del archivo y confirma la subida" do
    login_for_upload(@professor)

    assert_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ], 1 do
      post course_materials_path(@course), params: upload_params
    end

    assert_response :see_other
    assert_redirected_to new_course_material_path(@course)
    material = @course.materials.find_by!(title: "Guía de estudio")
    assert material.file.attached?
    assert_equal PDF_BYTES, material.file.download
    assert_equal "guia.pdf", material.file.filename.to_s

    follow_redirect!
    assert_response :success
    assert_select "[role=status]", text: /Material subido correctamente/
  end

  test "el coordinador puede subir si su cuenta es de profesor" do
    login_for_upload(@coordinator)
    get course_path(@coordinated_course)
    assert_response :success
    assert_select "a[href=?]", new_course_material_path(@coordinated_course), text: "Subir material"

    assert_difference "Material.count", 1 do
      post course_materials_path(@coordinated_course), params: upload_params
    end
    assert_redirected_to new_course_material_path(@coordinated_course)
  end

  test "director administrativo ayudante y alumno no pueden abrir ni enviar el formulario" do
    [ @director, @admin, @assistant, @student ].each do |user|
      login_for_upload(user)
      if user.director?
        patch university_selection_path, params: { university_id: @university.id }
      end

      get new_course_material_path(@course)
      assert_response :redirect, user.role
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]

      assert_no_difference [ "Material.count", "ActiveStorage::Blob.count" ] do
        post course_materials_path(@course), params: upload_params
      end
      assert_response :redirect, user.role
      sign_out :user
    end
  end

  test "un profesor sin participación en el curso no puede subir" do
    login_for_upload(@unassigned_professor)

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count" ] do
      post course_materials_path(@course), params: upload_params
    end
    assert_response :redirect
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  test "el alumno no ve el botón de subida en la sección que cursa" do
    login_for_upload(@student)
    get course_section_path(@course, @section)

    assert_response :success
    assert_select "a[href=?]", new_course_material_path(@course), count: 0
  end

  test "no permite abrir ni subir a un curso de otra universidad por su ID" do
    login_for_upload(@professor)
    get new_course_material_path(@other_course)
    assert_response :not_found

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count" ] do
      post course_materials_path(@other_course), params: upload_params
    end
    assert_response :not_found
  end

  test "ignora el curso y la universidad enviados dentro de los parámetros del archivo" do
    login_for_upload(@professor)
    attributes = upload_params
    attributes[:material].merge!(course_id: @other_course.id, university_id: @other_university.id)

    post course_materials_path(@course), params: attributes

    assert_redirected_to new_course_material_path(@course)
    material = Material.find_by!(title: "Guía de estudio")
    assert_equal @course.id, material.course_id
    ActsAsTenant.with_tenant(@university) do
      assert_equal @university.id, material.course.university_id
    end
  end

  test "la otra universidad puede subir sus propios archivos sin compartir adjuntos" do
    login_for_upload(@professor)
    post course_materials_path(@course), params: upload_params
    first = @course.materials.find_by!(title: "Guía de estudio")
    sign_out :user
    login_for_upload(@other_professor)

    post course_materials_path(@other_course), params: upload_params

    assert_redirected_to new_course_material_path(@other_course)
    second = @other_course.materials.find_by!(title: "Guía de estudio")
    assert_equal PDF_BYTES, second.file.download
    assert_not_equal first.file.blob.key, second.file.blob.key
    assert_not_equal first.file.blob_id, second.file.blob_id
  end

  test "un título inválido no guarda material ni blob ni adjunto" do
    login_for_upload(@professor)

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      post course_materials_path(@course), params: upload_params(title: " ")
    end
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /Título/
  end

  test "un archivo ausente o vacío se informa sin guardar registros" do
    login_for_upload(@professor)

    [ nil, multipart_upload(content: "") ].each do |file|
      assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
        post course_materials_path(@course), params: { material: { title: "Guía incompleta", file: file } }
      end
      assert_response :unprocessable_content
      assert_select "[role=alert]", text: /Archivo/
      assert_select "input[name='material[title]'][value=?]", "Guía incompleta"
    end
  end

  test "no acepta el signed ID de un archivo de otra universidad" do
    foreign = ActsAsTenant.with_tenant(@other_university) do
      Material.create!(course: @other_course, title: "Archivo ajeno", file: file_attributes)
    end
    login_for_upload(@professor)

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      post course_materials_path(@course), params: { material: { title: "Intruso", file: foreign.file.blob.signed_id } }
    end
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /desde tu equipo/
    assert foreign.reload.file.attached?
  end

  test "el endpoint global de direct uploads no permite saltarse B1" do
    payload = { blob: { filename: "intruso.pdf", content_type: "application/pdf", byte_size: PDF_BYTES.bytesize,
      checksum: Digest::MD5.base64digest(PDF_BYTES) } }

    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: payload
    end
    assert_redirected_to new_user_session_path

    login_for_upload(@professor)
    assert_no_difference "ActiveStorage::Blob.count" do
      post rails_direct_uploads_path, params: payload
    end
    assert_response :redirect
  end

  test "no existe una subida global fuera del contexto de un curso" do
    login_for_upload(@professor)

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count" ] do
      post "/materials", params: upload_params
    end
    assert_response :not_found
  end

  private

  def login_for_upload(user)
    sign_in user
    get root_path
    assert_response :redirect
  end

  def upload_params(title: "Guía de estudio")
    { material: { title: title, file: multipart_upload } }
  end
end
