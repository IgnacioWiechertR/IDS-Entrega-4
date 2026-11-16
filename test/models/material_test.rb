require "test_helper"
require_relative "../support/material_upload_data"

class MaterialTest < ActiveSupport::TestCase
  include MaterialUploadData

  setup do
    prepare_material_upload_data
    ActsAsTenant.current_tenant = @university
  end
  teardown { clear_uploaded_test_files }

  test "guarda el material y su archivo" do
    material = Material.new(course: @course, title: "Guía de estudio", file: file_attributes)

    assert material.save, material.errors.full_messages.join(", ")
    assert material.reload.file.attached?
    assert_equal @course, material.course
    assert_equal "guia.pdf", material.file.filename.to_s
    assert_equal "test", material.file.blob.service_name
    assert_equal PDF_BYTES, material.file.download
  end

  test "el título es obligatorio y no se guarda el archivo si falta" do
    material = Material.new(course: @course, title: " ", file: file_attributes)

    assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
      assert_not material.save
    end
    assert material.errors[:title].any?
  end

  test "el archivo es obligatorio" do
    material = Material.new(course: @course, title: "Guía")

    assert_not material.valid?
    assert material.errors[:file].any?
  end

  test "el archivo no puede estar vacío" do
    material = Material.new(course: @course, title: "Guía", file: file_attributes(content: ""))

    assert_not material.valid?
    assert_includes material.errors[:file], "no puede estar vacío"
  end

  test "el curso es obligatorio" do
    material = Material.new(title: "Guía", file: file_attributes)

    assert_not material.valid?
    assert material.errors[:course].any?
  end
end
