# B11: professors publish to a course or one of their sections. Reading and notifications come in later cards.
class AnnouncementsController < ApplicationController
  before_action :set_course

  def new
    @announcement = @course.announcements.new
    @announcement.section = permitted_sections.find(params[:section_id]) if params[:section_id].present?
    authorize! :create, @announcement
    @sections = permitted_sections.order(:number)
  end

  def create
    @announcement = @course.announcements.new(announcement_params)
    @announcement.author = current_user
    @announcement.section = permitted_sections.find(announcement_params[:section_id]) if announcement_params[:section_id].present?
    authorize! :create, @announcement

    if @announcement.save
      redirect_to(@announcement.section ? course_section_path(@course, @announcement.section) : courses_path,
        notice: "El anuncio fue publicado.", status: :see_other)
    else
      @sections = permitted_sections.order(:number)
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_course
    @course = Course.find(params[:course_id] || params.dig(:announcement, :course_id))
  end

  def announcement_params
    params.expect(announcement: [ :section_id, :subject, :body ])
  end

  def permitted_sections
    if CourseCoordinator.exists?(course_id: @course.id, user_id: current_user.id)
      @course.sections
    else
      @course.sections.joins(:section_staffs).where(section_staffs: { user_id: current_user.id, role: "profesor" })
    end
  end
end
