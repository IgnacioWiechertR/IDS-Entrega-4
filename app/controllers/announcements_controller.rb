# B11: professors publish to a course or one of their sections. Reading and notifications come in later cards.
class AnnouncementsController < ApplicationController
  before_action :set_course, only: %i[ new create ]
  before_action :set_announcement, only: %i[ show edit update destroy ]

  def index
    authorize! :read, Announcement
    @announcements = Announcement.all
  end

  def show
    authorize! :read, @announcement
  end

  def new
    @announcement = @course.announcements.new
    @announcement.section = permitted_sections.find(params[:section_id]) if params[:section_id].present?
    authorize! :create, @announcement
    @sections = permitted_sections.order(:number)
  end

  def edit
    authorize! :update, @announcement
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

  def update
    authorize! :update, @announcement
    if @announcement.update(announcement_params)
      redirect_to @announcement, notice: "Announcement was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! :destroy, @announcement
    @announcement.destroy!
    redirect_to announcements_path, notice: "Announcement was successfully destroyed.", status: :see_other
  end

  private

  def set_announcement
    @announcement = Announcement.find(params.expect(:id))
  end

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
