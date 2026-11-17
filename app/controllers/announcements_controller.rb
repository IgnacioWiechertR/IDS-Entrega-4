# B11: professors publish to a course or one of their sections.
# B12: professors and assistants read announcements from courses where they participate.
# B13: course professors correct the subject and body of an announcement.
# B16: students read course announcements and those addressed to their own section.
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
    @student_section = student_section_for(@announcement)
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
      AnnouncementPublishedNotificationJob.perform_later(@announcement.id, @announcement.university_id)
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

  # B19: the section where the user is an active student of the announcement's course (its own section, for a
  # section announcement), so the detail goes back to its Anuncios tab. Nil for staff and the director.
  def student_section_for(announcement)
    sections = Section.where(course_id: announcement.course_id)
      .where(id: Enrollment.where(student_id: current_user.id, active: true).select(:section_id))
    sections = sections.where(id: announcement.section_id) if announcement.section_id
    sections.joins(:term).order("terms.starts_on DESC").includes(:course).first
  end

  def readable_announcements
    # The director reads them all, in the active university (Announcement is scoped to it, A3).
    return Announcement.all if current_user.director?

    staff_courses = SectionStaff.joins(:section).where(user_id: current_user.id).select("sections.course_id")
    coordinated_courses = CourseCoordinator.where(user_id: current_user.id).select(:course_id)
    course_ids = Course.where(id: staff_courses).or(Course.where(id: coordinated_courses)).select(:id)

    announcements = Announcement.where(course_id: course_ids)
    return announcements unless current_user.student_account?

    enrolled_sections = Enrollment.where(student_id: current_user.id, active: true).select(:section_id)
    enrolled_courses = Section.where(id: enrolled_sections).select(:course_id)

    announcements.or(Announcement.where(course_id: enrolled_courses, section_id: nil))
      .or(Announcement.where(section_id: enrolled_sections))
  end
end
