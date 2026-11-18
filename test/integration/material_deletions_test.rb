require "test_helper"
require_relative "../support/material_deletion_data"

class MaterialDeletionsTest < ActionDispatch::IntegrationTest
  include MaterialDeletionData

  setup { prepare_material_deletion_data }
  teardown { clear_material_deletion_files }

  test "listado confirmación y eliminación exigen sesión" do
    assert_preserved do
      get course_material_deletions_path(@course)
      assert_redirected_to new_user_session_path
      get deletion_path
      assert_redirected_to new_user_session_path
      delete deletion_path, params: { confirmation: "eliminar" }
      assert_redirected_to new_user_session_path
    end
  end

  test "el curso y la sección ofrecen eliminación solo para material propio" do
    sign_in @professor
    get course_path(@course)
    assert_response :success
    assert_select "a[href=?]", course_material_deletions_path(@course), text: "Eliminar mi material"

    get course_section_path(@course, @section)
    assert_response :success
    assert_select "a[href=?]", deletion_path, text: "Eliminar"
    assert_select "a[href=?]", course_material_deletion_path(@course, @peer_material), count: 0

    get course_material_deletions_path(@course)
    assert_response :success
    assert_select "#deletable_material_#{@owned.id} a[href=?]", deletion_path
    assert_select "#deletable_material_#{@peer_material.id}", count: 0
    assert_select "#deletable_material_#{@foreign.id}", count: 0
    assert_select "#deletable_material_#{materials(:one).id}", count: 0
  end

  test "la pantalla de confirmación muestra el archivo y cancelar no elimina nada" do
    sign_in @professor
    assert_preserved do
      get deletion_path
      assert_response :success
      assert_select "h1", "¿Eliminar este material?"
      assert_select "#material_deletion_title", @owned.title
      assert_select "p", text: /guia-b4\.pdf/
      assert_select "form[action=?] input[name='_method'][value=delete]", deletion_path
      assert_select "form[action=?] input[name=confirmation][value=eliminar]", deletion_path
      assert_select "button", "Eliminar definitivamente"
      assert_select "a[href=?]", course_material_deletions_path(@course), text: "Cancelar"

      get course_material_deletions_path(@course)
      assert_response :success
    end
  end

  test "un GET con parámetros de confirmación tampoco elimina" do
    sign_in @professor
    assert_preserved do
      get deletion_path, params: { confirmation: "eliminar" }
      assert_response :success
    end
  end

  test "DELETE sin confirmación válida vuelve a la confirmación y conserva el material" do
    sign_in @professor
    [ nil, "", "false" ].each do |confirmation|
      assert_preserved do
        delete deletion_path, params: { confirmation: confirmation }
        assert_response :see_other
        assert_redirected_to deletion_path
        assert_equal "Confirma la eliminación para continuar.", flash[:alert]
      end
    end
  end

  test "el autor elimina el material y adjunto y la purga posterior borra blob y archivo" do
    blob = @owned.file.blob
    service = blob.service
    key = blob.key
    sign_in @professor

    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ blob ]) do
      assert_difference "Material.count", -1 do
        assert_difference "ActiveStorage::Attachment.count", -1 do
          assert_no_difference "ActiveStorage::Blob.count" do
            delete deletion_path, params: { confirmation: "eliminar" }
          end
        end
      end
    end

    assert_response :see_other
    assert_redirected_to course_material_deletions_path(@course)
    assert_not Material.exists?(@owned.id)
    assert service.exist?(key)
    assert_equal DELETION_PDF, @peer_material.reload.file.download

    assert_difference "ActiveStorage::Blob.count", -1 do
      perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    end
    assert_not service.exist?(key)
    assert_not ActiveStorage::Blob.exists?(blob.id)
    follow_redirect!
    assert_response :success
    assert_select "[role=status]", text: /Material eliminado correctamente/
    assert_select "#deletable_material_#{@owned.id}", count: 0
  end

  test "no se borra físicamente un blob que sigue asociado a otro material" do
    blob = @owned.file.blob
    @peer_material.file_attachment.update!(blob: blob)
    sign_in @professor

    delete deletion_path, params: { confirmation: "eliminar" }
    assert_response :see_other
    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)

    assert_not Material.exists?(@owned.id)
    assert ActiveStorage::Blob.exists?(blob.id)
    assert blob.service.exist?(blob.key)
    assert_equal DELETION_PDF, @peer_material.reload.file.download
  end

  test "se puede eliminar un material propio cuyo archivo físico ya falta" do
    blob = @owned.file.blob
    blob.service.delete(blob.key)
    sign_in @professor

    assert_difference "Material.count", -1 do
      delete deletion_path, params: { confirmation: "eliminar" }
    end
    assert_response :see_other
    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert_equal DELETION_PDF, @peer_material.reload.file.download
  end

  test "un material propio sin adjunto se elimina sin encolar purga" do
    @owned.file.purge
    clear_enqueued_jobs
    sign_in @professor

    assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
      assert_difference "Material.count", -1 do
        delete deletion_path, params: { confirmation: "eliminar" }
      end
    end
    assert_response :see_other
  end

  test "si la destrucción se aborta no se elimina el adjunto ni se encola purga" do
    target_id = @owned.id
    callback = ->(record) { throw(:abort) if record.id == target_id }
    Material.set_callback(:destroy, :before, callback)
    sign_in @professor

    assert_preserved do
      delete deletion_path, params: { confirmation: "eliminar" }
      assert_response :see_other
      assert_redirected_to course_material_deletions_path(@course)
      assert_equal "No se pudo eliminar el material. Vuelve a intentarlo.", flash[:alert]
    end
  ensure
    Material.skip_callback(:destroy, :before, callback) if callback
  end

  test "otro profesor asignado al mismo curso no puede confirmar ni eliminar" do
    sign_in @peer
    assert_preserved do
      get deletion_path
      assert_redirected_to courses_path
      delete deletion_path, params: { confirmation: "eliminar", uploaded_by_id: @peer.id }
      assert_redirected_to courses_path
    end

    get course_material_deletions_path(@course)
    assert_response :success
    assert_select "#deletable_material_#{@owned.id}", count: 0
    assert_select "#deletable_material_#{@peer_material.id}"
  end

  test "ser coordinador no permite eliminar material de otro profesor" do
    sign_in @professor
    assert_no_difference [ "Material.count", "ActiveStorage::Attachment.count", "ActiveStorage::Blob.count" ] do
      assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
        delete course_material_deletion_path(@course, @peer_material), params: { confirmation: "eliminar" }
      end
    end
    assert_redirected_to courses_path
    assert_equal @peer.id, @peer_material.reload.uploaded_by_id
    assert_equal DELETION_PDF, @peer_material.file.download
  end

  test "director administrativo ayudante y alumno no pueden eliminar" do
    %i[director administrativo ayudante alumno].each do |role|
      sign_in users(role)
      patch university_selection_path, params: { university_id: @course.university_id } if role == :director
      assert_preserved do
        get deletion_path
        assert_response :redirect
        delete deletion_path, params: { confirmation: "eliminar" }
        assert_response :redirect
        assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      end
      get course_material_deletions_path(@course)
      assert_response :redirect
      sign_out :user
    end
  end

  test "el autor coordinador conserva el permiso aunque no dicte una sección" do
    section_staffs(:one).destroy!
    sign_in @professor

    assert_difference "Material.count", -1 do
      delete deletion_path, params: { confirmation: "eliminar" }
    end
    assert_response :see_other
  end

  test "quitar participación o cambiar el rol revoca enlaces guardados" do
    section_staffs(:one).destroy!
    course_coordinators(:one).destroy!
    sign_in @professor
    assert_preserved do
      delete deletion_path, params: { confirmation: "eliminar" }
      assert_redirected_to courses_path
    end

    @professor.update!(role: "administrativo")
    sign_in @professor
    assert_preserved do
      delete deletion_path, params: { confirmation: "eliminar" }
      assert_redirected_to accounts_path
    end
  end

  test "los materiales antiguos sin autor no se atribuyen ni se eliminan" do
    sign_in @professor
    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
        delete course_material_deletion_path(@course, materials(:one)),
          params: { confirmation: "eliminar", uploaded_by_id: @professor.id }
      end
    end
    assert_redirected_to courses_path
    assert_nil materials(:one).reload.uploaded_by_id
  end

  test "los IDs de otra universidad no permiten confirmar ni eliminar" do
    [ :get, :delete ].each do |verb|
      sign_in @professor
      assert_preserved do
        public_send(verb, course_material_deletion_path(courses(:two), @foreign), params: { confirmation: "eliminar" })
        assert_response :not_found
      end
    end
  end

  test "cada universidad puede eliminar su propio material sin afectar a la otra" do
    sign_in users(:profesor_iusa)
    assert_difference "Material.count", -1 do
      delete course_material_deletion_path(courses(:two), @foreign), params: { confirmation: "eliminar" }
    end
    assert_response :see_other
    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    assert_not Material.exists?(@foreign.id)
    assert_equal DELETION_PDF, @owned.reload.file.download
  end

  test "un material no puede anidarse bajo otro curso en la URL" do
    sign_in @professor
    assert_preserved do
      delete course_material_deletion_path(@course, @foreign), params: { confirmation: "eliminar" }
      assert_response :not_found
    end
  end

  test "los parámetros no permiten eliminar otro material o blob" do
    peer_blob = @peer_material.file.blob
    sign_in @professor
    assert_difference "Material.count", -1 do
      delete deletion_path, params: { confirmation: "eliminar", uploaded_by_id: @peer.id,
        blob_id: peer_blob.id, signed_id: peer_blob.signed_id, material_id: @peer_material.id,
        university_id: universities(:iusa).id }
    end
    assert_response :see_other
    perform_enqueued_jobs(only: ActiveStorage::PurgeJob)
    assert_equal DELETION_PDF, @peer_material.reload.file.download
    assert ActiveStorage::Blob.exists?(peer_blob.id)
    assert_equal DELETION_PDF, @foreign.reload.file.download
  end

  test "una segunda eliminación responde 404 y no encola otra purga" do
    sign_in @professor
    delete deletion_path, params: { confirmation: "eliminar" }
    assert_response :see_other

    assert_no_difference [ "Material.count", "ActiveStorage::Attachment.count", "ActiveStorage::Blob.count" ] do
      assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) do
        delete deletion_path, params: { confirmation: "eliminar" }
        assert_response :not_found
      end
    end
  end

  test "el scaffold global no proporciona otra ruta para borrar" do
    sign_in @professor
    assert_preserved do
      delete "/materials/#{@owned.id}", params: { confirmation: "eliminar" }
      assert_response :not_found
    end
  end

  test "el título del material se escapa en la confirmación" do
    @owned.update!(title: '<script>alert("x")</script>')
    sign_in @professor
    get deletion_path

    assert_response :success
    assert_select "#material_deletion_title", text: '<script>alert("x")</script>'
    assert_select "script", text: /alert/, count: 0
    assert_includes response.headers["Cache-Control"], "private"
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "el listado vacío informa que no hay material propio para eliminar" do
    @owned.destroy!
    clear_enqueued_jobs
    sign_in @professor

    get course_material_deletions_path(@course)

    assert_response :success
    assert_select "#deletable_materials_empty", text: /Todavía no tienes material propio/
    assert_select "#deletable_materials", count: 0
  end

  private

  def deletion_path
    course_material_deletion_path(@course, @owned)
  end

  def assert_preserved
    blob_id = @owned.file.blob_id
    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      assert_no_enqueued_jobs(only: ActiveStorage::PurgeJob) { yield }
    end
    @owned.reload
    assert_equal @professor.id, @owned.uploaded_by_id
    assert_equal "Material propio B4", @owned.title
    assert_equal blob_id, @owned.file.blob_id
    assert_equal DELETION_PDF, @owned.file.download
  end
end
