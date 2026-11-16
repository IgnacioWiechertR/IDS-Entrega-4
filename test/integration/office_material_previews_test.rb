require "test_helper"
require_relative "../support/material_read_data"
require_relative "../support/office_preview_data"

class OfficeMaterialPreviewsTest < ActionDispatch::IntegrationTest
  include MaterialReadData
  include OfficePreviewData

  setup { prepare_material_read_data }
  teardown { clear_material_read_files }

  %w[docx xlsx pptx odp].each do |extension|
    test "el material #{extension} muestra detalle sin descargarlo ni convertirlo" do
      material = read_material(filename: "material.#{extension}", content: office_document(extension))
      sign_in users(:alumno)

      get course_material_path(@course, material)
      assert_response :success
      assert_select "#material_details", text: /material\.#{extension}/
      assert_select "#preview_unavailable", text: /La vista previa no está disponible/
      assert_select "iframe", count: 0

      downloads = []
      observer = ->(event) { downloads << event }
      ActiveSupport::Notifications.subscribed(observer, /service_(download|streaming_download|download_chunk)\.active_storage/) do
        assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
          get preview_course_material_path(@course, material)
        end
      end

      assert_response :unprocessable_content
      assert_select "[role=status]", text: /Solo se pueden visualizar archivos PDF y de texto/
      assert_empty downloads
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal "material.#{extension}", material.reload.file.filename.to_s
    end
  end
end
