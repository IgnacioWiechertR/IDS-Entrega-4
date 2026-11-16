require "test_helper"
require_relative "../support/material_read_data"
require_relative "../support/office_preview_data"

class OfficeMaterialPreviewsTest < ActionDispatch::IntegrationTest
  include MaterialReadData
  include OfficePreviewData

  setup { prepare_material_read_data }
  teardown { clear_material_read_files }

  %w[docx xlsx pptx odp].each do |extension|
    test "el alumno ve contenido #{extension} convertido realmente a PDF" do
      material = read_material(filename: "material.#{extension}", content: office_document(extension))
      sign_in users(:alumno)

      get course_material_path(@course, material)
      assert_response :success
      assert_select "iframe[src=?]", preview_course_material_path(@course, material)

      assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
        get preview_course_material_path(@course, material)
      end

      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert response.body.start_with?("%PDF-")
      assert_operator response.body.bytesize, :>, 1_000
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal "material.#{extension}", material.reload.file.filename.to_s
    end
  end
end
