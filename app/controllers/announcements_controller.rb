# B11: professors publish to a course or one of their sections.
# B12: professors and assistants read announcements from courses where they participate.
# B13: course professors correct the subject and body of an announcement.
class AnnouncementsController < ApplicationController
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
      redirect_to(@announcement.section ? course_section_path(@course, @announcement.section) : course_path(@course),
        notice: "El anuncio fue publicado.", status: :see_other)
    else
      @sections = permitted_sections.order(:number)
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize! :update, @announcement
    if @announcement.update(announcement_update_params)
      redirect_to @announcement, notice: "El anuncio fue actualizado.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! :destroy, @announcement
    @announcement.destroy!
    redirect_to announcements_path, notice: "El anuncio fue eliminado.", status: :see_other
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

  def announcement_update_params
    params.expect(announcement: [ :subject, :body ])
  end

  def permitted_sections
    if CourseCoordinator.exists?(course_id: @course.id, user_id: current_user.id)
      @course.sections
    else
      @course.sections.joins(:section_staffs).where(section_staffs: { user_id: current_user.id, role: "profesor" })
    end
  end

  def readable_announcements
    staff_courses = SectionStaff.joins(:section).where(user_id: current_user.id).select("sections.course_id")
    coordinated_courses = CourseCoordinator.where(user_id: current_user.id).select(:course_id)
    course_ids = Course.where(id: staff_courses).or(Course.where(id: coordinated_courses)).select(:id)

    Announcement.where(course_id: course_ids)
  end
end
