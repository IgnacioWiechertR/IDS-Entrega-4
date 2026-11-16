require "fileutils"
require "tmpdir"
require "timeout"

# Office documents are converted locally. No signed URLs are sent to external viewers.
class OfficePreviewService
  class Unavailable < StandardError; end

  TIMEOUT = 30
  MAX_PDF_SIZE = 50_000_000
  PROFILE_SETTINGS = <<~XML.freeze
    <?xml version="1.0" encoding="UTF-8"?>
    <oor:items xmlns:oor="http://openoffice.org/2001/registry">
      <item oor:path="/org.openoffice.Office.Common/Security/Scripting">
        <prop oor:name="DisableMacrosExecution" oor:op="fuse"><value>true</value></prop>
        <prop oor:name="DisableActiveContent" oor:op="fuse"><value>true</value></prop>
        <prop oor:name="BlockUntrustedRefererLinks" oor:op="fuse"><value>true</value></prop>
      </item>
    </oor:items>
  XML

  def initialize(executable: ENV.fetch("LIBREOFFICE_PATH", "libreoffice"), timeout: TIMEOUT)
    @executable = executable
    @timeout = timeout
  end

  def call(source_path, extension:)
    raise Unavailable unless MaterialPreviewService::OFFICE_EXTENSIONS.include?(extension)

    Dir.mktmpdir("sga-office-preview-") do |directory|
      source = File.join(directory, "material.#{extension}")
      profile = File.join(directory, "profile")
      FileUtils.mkdir_p(File.join(profile, "user"))
      File.write(File.join(profile, "user", "registrymodifications.xcu"), PROFILE_SETTINGS)
      FileUtils.cp(source_path, source)
      command = [ @executable, "-env:UserInstallation=file://#{profile}", "--headless", "--nologo", "--nodefault",
        "--norestore", "--convert-to", "pdf", "--outdir", directory, source ]
      run(command)
      pdf = File.join(directory, "material.pdf")
      raise Unavailable unless File.file?(pdf) && File.size(pdf).between?(1, MAX_PDF_SIZE)
      raise Unavailable unless File.binread(pdf, 5) == "%PDF-"

      File.binread(pdf)
    end
  rescue Errno::ENOENT, Errno::EACCES
    raise Unavailable
  end

  private

  def run(command)
    pid = Process.spawn(*command, in: File::NULL, out: File::NULL, err: File::NULL, pgroup: true,
      rlimit_cpu: TIMEOUT, rlimit_fsize: MAX_PDF_SIZE)
    status = Timeout.timeout(@timeout) { Process.wait2(pid).last }
    raise Unavailable unless status.success?
  rescue Timeout::Error
    raise Unavailable
  ensure
    if pid
      begin
        Process.kill("KILL", -pid)
      rescue Errno::ESRCH
        # The converter already exited.
      end
      begin
        Process.wait(pid)
      rescue Errno::ECHILD
        # wait2 already reaped the converter.
      end
    end
  end
end
