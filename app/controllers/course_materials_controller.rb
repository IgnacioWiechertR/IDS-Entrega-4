# B2 reads through the course's existing permissions, separately from B1's upload controller.
class CourseMaterialsController < ApplicationController
  before_action :set_readable_course
  before_action :set_material, only: %i[ show preview ]
  before_action :prevent_shared_caching

  def index
    @materials = @course.materials.with_attached_file.order(created_at: :desc, id: :desc)
  end

  def show
    @preview = MaterialPreviewService.new(@material.file)
  end

  def preview
    service = MaterialPreviewService.new(@material.file)
    if service.text?
      @text, @truncated = service.text
      render :preview_text, layout: false
    else
      send_data service.pdf, type: "application/pdf", disposition: "inline",
        filename: "#{@material.file.filename.base}.pdf"
    end
  rescue MaterialPreviewService::Unavailable, OfficePreviewService::Unavailable, ActiveStorage::FileNotFoundError
    render :preview_unavailable, layout: false, status: :unprocessable_content
  end

  private

  def set_readable_course
    @course = Course.find(params.expect(:course_id))
    authorize! :read, @course
  end

  def set_material
    @material = @course.materials.with_attached_file.find(params.expect(:id))
  end

  def prevent_shared_caching
    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
  end
end
