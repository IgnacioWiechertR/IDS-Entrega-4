# B11: professors publish to a course or one of their sections.
# B12: professors and assistants read announcements from courses where they participate.
class AnnouncementsController < ApplicationController
  before_action :prevent_shared_caching
  before_action :set_course, only: %i[ new create ]
  before_action :set_announcement, only: %i[ edit update destroy ]

  def index
    authorize! :index, :announcements
    @announcements = readable_announcements.includes(:course, :section, :author)
      .order(created_at: :desc, id: :desc)
  end

  def show
    authorize! :index, :announcements
    @announcement = readable_announcements.includes(:course, :section, :author).find(params.expect(:id))
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
      AnnouncementPublishedNotificationJob.perform_later(@announcement.university_id, @announcement.id, @announcement.student_recipients.ids)
      redirect_to(@announcement.section ? course_section_path(@course, @announcement.section) : course_path(@course),
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

  def readable_announcements
    Announcement.readable_by(current_user)
  end

  def prevent_shared_caching
    response.headers["Cache-Control"] = "private, no-store"
  end
end
