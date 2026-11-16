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

  test "acepta un archivo de exactamente 50 MB" do
    with_sized_pdf(50_000_000) do |io|
      material = Material.new(course: @course, title: "Documento grande",
        file: { io: io, filename: "grande.pdf", content_type: "application/pdf" })

      assert material.valid?, material.errors.full_messages.join(", ")
    end
  end

  test "rechaza un byte sobre 50 MB sin guardar material ni adjuntos" do
    with_sized_pdf(50_000_001) do |io|
      material = Material.new(course: @course, title: "Documento demasiado grande",
        file: { io: io, filename: "grande.pdf", content_type: "application/pdf" })

      assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
        assert_not material.save
      end
      assert_includes material.errors[:file], "no puede superar 50 MB"
    end
  end

  test "rechaza el contenido HTML renombrado como PDF" do
    material = Material.new(course: @course, title: "Falso documento",
      file: file_attributes(content: "<html><body>No es PDF</body></html>"))

    assert_not material.valid?
    assert material.errors[:file].any?
  end

  test "valida el formato también al reemplazar un archivo existente" do
    material = Material.create!(course: @course, title: "Guía", file: file_attributes)
    material.file = file_attributes(content: "contenido no permitido", filename: "programa.exe")

    assert_not material.valid?
    assert material.errors[:file].any?
  end
end
