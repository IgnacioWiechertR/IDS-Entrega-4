class MaterialDownloadsController < ApplicationController
  before_action :prevent_shared_caching
  before_action :set_readable_course

  def index
    @materials = @course.materials.with_attached_file.order(created_at: :desc, id: :desc)
  end

  def show
    material = @course.materials.with_attached_file.find(params.expect(:material_id))
    return unavailable unless material.file.attached?

    blob = material.file.blob
    return unavailable unless blob.service.exist?(blob.key)

    response.headers["Content-Type"] = "application/octet-stream"
    response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
      disposition: "attachment", filename: blob.filename.sanitized)
    response.headers["Content-Length"] = blob.byte_size.to_s
    response.headers["Accept-Ranges"] = "none"
    # Rack::ETag must not consume and buffer the body to calculate a digest.
    response.headers["Last-Modified"] = blob.created_at.httpdate
    self.response_body = MaterialDownloadBody.new(blob)
  rescue ActiveStorage::FileNotFoundError
    unavailable
  end

  private

  def set_readable_course
    @course = Course.find(params.expect(:course_id))
    authorize! :read, @course
  end

  def prevent_shared_caching
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
  end

  def unavailable
    render plain: "El archivo no está disponible para descargar.", status: :not_found
  end
end
