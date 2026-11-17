# The syllabus of a course in one term (?term_id=): anyone who can read the course views and downloads it, and the
# administrativo or the coordinator of that term uploads or replaces it. Its content is never edited here.
class SyllabiController < ApplicationController
  before_action :prevent_shared_caching, only: %i[ show preview download ]
  before_action :set_course_and_term
  before_action :set_readable_syllabus, only: %i[ show preview download ]

  # GET /courses/1/syllabus?term_id=1: a page that shows the PDF, like the material preview (B2).
  def show
  end

  # GET /courses/1/syllabus/preview?term_id=1: the PDF itself, inline, for the viewer of the page.
  def preview
    send_data MaterialPreviewService.new(@syllabus.file).pdf, type: "application/pdf", disposition: "inline",
      filename: @syllabus.file.filename.to_s
  rescue MaterialPreviewService::Unavailable, ActiveStorage::FileNotFoundError
    unavailable
  end

  # GET /courses/1/syllabus/download?term_id=1: the original file, like the materials (B5).
  def download
    blob = @syllabus.file.blob
    return unavailable unless blob && blob.service.exist?(blob.key)

    response.headers["Content-Type"] = "application/octet-stream"
    response.headers["Content-Disposition"] = ActionDispatch::Http::ContentDisposition.format(
      disposition: "attachment", filename: blob.filename.sanitized)
    response.headers["Content-Length"] = blob.byte_size.to_s
    response.headers["Last-Modified"] = blob.created_at.httpdate
    self.response_body = MaterialDownloadBody.new(blob)
  rescue ActiveStorage::FileNotFoundError
    unavailable
  end

  # GET /courses/1/syllabus/new?term_id=1: upload a syllabus, or replace the current one.
  def new
    return locked if locked_for_uploader?

    authorize! :upload, @syllabus
  end

  # POST /courses/1/syllabus
  def create
    return locked if locked_for_uploader?

    authorize! :upload, @syllabus
    upload = params.dig(:syllabus, :file)
    replacing = @syllabus.persisted?

    # A fresh multipart upload only, never an existing blob's signed ID (like B1).
    if upload.is_a?(ActionDispatch::Http::UploadedFile)
      @syllabus.file = upload
      @syllabus.uploaded_by = current_user
      if @syllabus.save
        redirect_to course_syllabus_path(@course, term_id: @term.id), status: :see_other,
          notice: replacing ? "El syllabus fue reemplazado." : "El syllabus fue subido."
        return
      end
    else
      @syllabus.errors.add(:file, upload.present? ? :from_device : :blank)
    end

    render :new, status: :unprocessable_content
  rescue MaterialStorageService::UniversityNotConfigured
    @syllabus.errors.add(:file, "no se pudo guardar porque el almacenamiento de esta universidad no está configurado")
    render :new, status: :unprocessable_content
  end

  private

  # Course and Term are scoped to the active university (A3), so ids of the other one are not found.
  def set_course_and_term
    @course = Course.find(params.expect(:course_id))
    @term = Term.find(params[:term_id] || params.dig(:syllabus, :term_id))
    @syllabus = @course.syllabi.with_attached_file.find_or_initialize_by(term: @term)
    @syllabus.university ||= @course.university
  end

  # Reading follows the course: whoever can read the course reads its syllabus.
  def set_readable_syllabus
    authorize! :read, @course
    raise ActiveRecord::RecordNotFound unless @syllabus.persisted? && @syllabus.file.attached?
  end

  # Someone who could upload it, if it were not locked, gets the reason instead of a generic denial.
  def locked_for_uploader?
    @syllabus.locked? && can?(:upload, Syllabus.new(course: @course, term: @term, university: @course.university))
  end

  def locked
    authorize! :read, @course
    redirect_to course_syllabus_path(@course, term_id: @term.id), status: :see_other,
      alert: "El syllabus no se puede reemplazar porque el período #{@term.name} ya comenzó."
  end

  def prevent_shared_caching
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
  end

  def unavailable
    render plain: "El archivo no está disponible.", status: :not_found
  end
end
