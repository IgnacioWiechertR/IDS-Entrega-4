require "test_helper"
require_relative "../support/material_download_data"

class PrivateAttachmentRoutesTest < ActionDispatch::IntegrationTest
  include MaterialDownloadData

  setup { prepare_material_download_data }
  teardown { clear_material_download_files }

  test "las rutas públicas de blob proxy representación y disco están deshabilitadas aun con tokens válidos" do
    blob = @foreign_material.file.blob
    signed_blob = blob.signed_id
    disk_key = ActiveStorage.verifier.generate(
      { key: blob.key, disposition: "attachment", content_type: blob.content_type, service_name: blob.service_name },
      expires_in: 5.minutes, purpose: :blob_key)
    variation = ActiveStorage::Variation.encode(resize_to_limit: [ 100, 100 ])
    paths = [
      "/rails/active_storage/blobs/redirect/#{signed_blob}/guia.pdf",
      "/rails/active_storage/blobs/proxy/#{signed_blob}/guia.pdf",
      "/rails/active_storage/blobs/#{signed_blob}/guia.pdf",
      "/rails/active_storage/representations/redirect/#{signed_blob}/#{variation}/guia.pdf",
      "/rails/active_storage/representations/proxy/#{signed_blob}/#{variation}/guia.pdf",
      "/rails/active_storage/representations/#{signed_blob}/#{variation}/guia.pdf",
      "/rails/active_storage/disk/#{disk_key}/guia.pdf"
    ]

    [ nil, users(:alumno), users(:administrativo), users(:alumno_iusa) ].each do |user|
      paths.each do |path|
        sign_in user if user
        events = observe_download_storage do
          get path
          assert_response :not_found
        end
        assert_empty events
      end
      sign_out :user if user
    end
  end

  test "ni direct uploads ni cargas a disco pueden crear blobs fuera de B1" do
    token = ActiveStorage.verifier.generate({ key: "carga-indebida", service_name: "test", content_type: "application/pdf",
      content_length: DOWNLOAD_PDF.bytesize, checksum: Digest::MD5.base64digest(DOWNLOAD_PDF) },
      expires_in: 5.minutes, purpose: :blob_token)

    [ nil, users(:profesor) ].each do |user|
      sign_in user if user
      assert_no_difference [ "Material.count", "ActiveStorage::Blob.count", "ActiveStorage::Attachment.count" ] do
        post rails_direct_uploads_path, params: { blob: { filename: "indebido.pdf", byte_size: DOWNLOAD_PDF.bytesize,
          content_type: "application/pdf", checksum: Digest::MD5.base64digest(DOWNLOAD_PDF) } }
        if user
          assert_equal "No tienes permiso para ver esa página.", flash[:alert]
        else
          assert_redirected_to new_user_session_path
        end

        sign_in user if user
        put "/rails/active_storage/disk/#{token}", params: DOWNLOAD_PDF, headers: { "Content-Type" => "application/pdf" }
        assert_response :not_found
      end
      sign_out :user if user
    end
  end
end
