require "test_helper"
require_relative "../support/material_upload_data"

class MaterialFileFormatTest < ActiveSupport::TestCase
  include MaterialUploadData

  test "acepta PDF y su extensión en mayúsculas" do
    assert supported?("guia.pdf", PDF_BYTES)
    assert supported?("GUIA.PDF", PDF_BYTES)
  end

  test "acepta documentos Office actuales OpenDocument y equivalentes de Apple" do
    %w[docx xlsx pptx ppsx odt ods odp pages numbers key].each do |extension|
      assert supported?("documento.#{extension}", document_archive(extension: extension)), extension
    end
  end

  test "acepta los contenedores de Word Excel y PowerPoint clásicos" do
    container = "\xD0\xCF\x11\xE0\xA1\xB1\x1A\xE1".b + ("\0" * 512)
    %w[doc xls ppt pps].each do |extension|
      assert supported?("documento.#{extension}", container), extension
    end
  end

  test "acepta RTF y archivos de texto CSV TSV y Markdown" do
    assert supported?("guia.rtf", '{\rtf1\ansi Material de prueba}')
    assert supported?("guia.txt", "Introducción al curso\n")
    assert supported?("notas.csv", "nombre,nota\nAna,6.0\n")
    assert supported?("notas.tsv", "nombre\tnota\nAna\t6.0\n")
    assert supported?("guia.md", "# Material\nIntroducción\n")
  end

  test "acepta texto UTF16 exportado desde una hoja de cálculo" do
    content = "\xFF\xFE".b + "nombre\tnota\r\nAna\t6.0\r\n".encode(Encoding::UTF_16LE).b

    assert supported?("notas.tsv", content)
  end

  test "rechaza extensiones ajenas a documentos y los accesos directos de Google" do
    %w[exe zip html jpg gdoc gsheet gslides].each do |extension|
      assert_not supported?("archivo.#{extension}", "contenido"), extension
    end
  end

  test "la extensión o el MIME declarado no convierten texto en un documento Office" do
    assert_not supported?("guia.docx", "Solo es texto")
    assert_not supported?("guia.pdf", "<html><body>Texto</body></html>")
  end

  test "rechaza datos binarios ocultos después del primer bloque de un archivo de texto" do
    assert_not supported?("guia.txt", ("texto\n" * 2_000) + "\0datos binarios")
  end

  test "conserva la posición del archivo después de comprobar su formato" do
    io = StringIO.new(PDF_BYTES)
    io.pos = 8

    assert MaterialFileFormat.allowed?("guia.pdf", io: io)
    assert_equal 8, io.pos
  end

  private

  def supported?(filename, content)
    MaterialFileFormat.allowed?(filename, io: StringIO.new(content))
  end
end
