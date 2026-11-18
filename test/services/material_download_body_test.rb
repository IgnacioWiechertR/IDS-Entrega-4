require "test_helper"
require "digest"
require "tempfile"

class MaterialDownloadBodyTest < ActiveSupport::TestCase
  class ChunkSource
    attr_reader :reads, :closed

    def initialize
      @reads = 0
      @closed = false
    end

    def download
      raise "Se pidió el archivo completo en memoria" unless block_given?
      3.times do
        @reads += 1
        yield "parte-#{@reads}"
      end
    ensure
      @closed = true
    end
  end

  test "Rack ETag no lee ni almacena el archivo antes de que el cliente consuma el cuerpo" do
    source = ChunkSource.new
    body = MaterialDownloadBody.new(source)
    headers = { "last-modified" => Time.utc(2026, 11, 16).httpdate, "cache-control" => "private, no-store" }
    app = Rack::ETag.new(->(_env) { [ 200, headers, body ] })
    _, result_headers, result_body = app.call({})

    assert_equal 0, source.reads
    assert_nil result_headers["etag"]
    assert_equal [ "parte-1" ], result_body.each.take(1)
    assert_equal 1, source.reads
    assert source.closed
  end

  test "un archivo real de 12 MB se transmite por varios bloques conservando su checksum" do
    blob = nil
    Tempfile.create([ "material-b5", ".pdf" ]) do |file|
      file.binmode
      file.write("%PDF-1.4\n")
      file.truncate(12_000_000)
      file.rewind
      expected = Digest::SHA256.file(file.path).hexdigest
      blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: "material-grande.pdf")
      sizes = []
      digest = Digest::SHA256.new

      MaterialDownloadBody.new(blob).each do |chunk|
        sizes << chunk.bytesize
        digest << chunk
      end

      assert_equal 12_000_000, sizes.sum
      assert_operator sizes.length, :>, 1
      assert_operator sizes.max, :<=, 5.megabytes
      assert_equal expected, digest.hexdigest
    end
  ensure
    blob&.service&.delete(blob.key)
  end
end
