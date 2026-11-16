require "test_helper"
require_relative "../support/material_read_data"

class MaterialPreviewServiceTest < ActiveSupport::TestCase
  include MaterialReadData

  setup { prepare_material_read_data }
  teardown { clear_material_read_files }

  test "admite PDF y reconoce texto sin abrir una descarga pública" do
    pdf = MaterialPreviewService.new(@material.file)
    assert pdf.available?
    assert_not pdf.text?
    assert_equal read_pdf_bytes, pdf.pdf

    text = read_material(filename: "datos.CSV", content: "curso,alumnos\nprogramación,30\n")
    service = MaterialPreviewService.new(text.file)
    assert service.available?
    assert service.text?
    assert_equal [ "curso,alumnos\nprogramación,30\n", false ], service.text
  end

  test "decodifica textos UTF16 y elimina su marca de orden de bytes" do
    %w[UTF-16LE UTF-16BE].each do |encoding|
      content = "\uFEFFTítulo\tContenido\n".encode(encoding)
      text = read_material(filename: "datos.tsv", content: content)
      assert_equal [ "Título\tContenido\n", false ], MaterialPreviewService.new(text.file).text
    end
  end

  test "el texto binario no se presenta como contenido legible" do
    material = read_material(filename: "falso.txt", content: "contenido\x00binario")
    assert_raises(MaterialPreviewService::Unavailable) { MaterialPreviewService.new(material.file).text }
  end

  test "un PDF renombrado y los formatos ejecutables no se presentan inline" do
    fake = read_material(filename: "falso.pdf", content: "<html>No es PDF</html>")
    assert_raises(MaterialPreviewService::Unavailable) { MaterialPreviewService.new(fake.file).pdf }
    executable = read_material(filename: "programa.exe", content: "contenido")
    service = MaterialPreviewService.new(executable.file)
    assert_not service.available?
    assert_raises(MaterialPreviewService::Unavailable) { service.pdf }
  end

  test "los registros sin adjunto no tienen vista previa" do
    service = MaterialPreviewService.new(materials(:one).file)
    assert_not service.available?
    assert_raises(MaterialPreviewService::Unavailable) { service.pdf }
  end

  test "no intenta previsualizar archivos históricos mayores que el límite de B1" do
    @material.file.blob.update!(byte_size: 50_000_001)
    service = MaterialPreviewService.new(@material.file)
    assert_not service.available?
    assert_raises(MaterialPreviewService::Unavailable) { service.pdf }
  end
end
