require "test_helper"
require "rbconfig"

class OfficePreviewServiceTest < ActiveSupport::TestCase
  test "convierte en un directorio privado con macros desactivadas y elimina los temporales" do
    script = <<~RUBY
      require "cgi"
      output_dir = ARGV.fetch(ARGV.index("--outdir") + 1)
      profile = ARGV.find { |argument| argument.start_with?("-env:UserInstallation=") }.delete_prefix("-env:UserInstallation=file://")
      settings = File.read(File.join(profile, "user", "registrymodifications.xcu"))
      abort unless settings.include?('DisableMacrosExecution') && settings.include?('DisableActiveContent')
      abort unless File.read(ARGV.last) == "contenido original"
      File.write(File.join(output_dir, "material.pdf"), "%PDF-1.4\\n" + output_dir)
    RUBY
    with_converter(script) do |service, source|
      pdf = service.call(source, extension: "docx")
      assert pdf.start_with?("%PDF-1.4\n")
      directory = pdf.split("\n").last
      assert_not Dir.exist?(directory)
      assert_equal "contenido original", File.read(source)
    end
  end

  test "un ejecutable no instalado produce un error controlado" do
    assert_raises(OfficePreviewService::Unavailable) do
      OfficePreviewService.new(executable: "/no-existe/libreoffice").call(__FILE__, extension: "docx")
    end
  end

  test "el convertidor debe terminar correctamente y generar un PDF verdadero" do
    [ "exit 1", "exit 0", 'File.write(File.join(ARGV.fetch(ARGV.index("--outdir") + 1), "material.pdf"), "no es un pdf")' ].each do |script|
      with_converter(script) do |service, source|
        assert_raises(OfficePreviewService::Unavailable) { service.call(source, extension: "xlsx") }
      end
    end
  end

  test "un convertidor bloqueado se termina al alcanzar el tiempo máximo" do
    with_converter("sleep 20", timeout: 0.2) do |service, source|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      assert_raises(OfficePreviewService::Unavailable) { service.call(source, extension: "pptx") }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert_operator elapsed, :<, 5
    end
  end

  test "no acepta extensiones con rutas ni argumentos del intérprete" do
    %w[../pdf docx;echo html exe].each do |extension|
      assert_raises(OfficePreviewService::Unavailable) do
        OfficePreviewService.new.call(__FILE__, extension: extension)
      end
    end
  end

  private

  def with_converter(script, timeout: 5)
    Dir.mktmpdir("b2-converter-test-") do |directory|
      executable = File.join(directory, "converter")
      source = File.join(directory, "source with spaces.docx")
      File.write(executable, "#!#{RbConfig.ruby}\n#{script}")
      File.chmod(0o700, executable)
      File.write(source, "contenido original")
      yield OfficePreviewService.new(executable: executable, timeout: timeout), source
    end
  end
end
