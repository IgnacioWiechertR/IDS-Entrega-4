# Sections of a course (A18): the administrativo creates, edits and deletes them in their university; the
# coordinator of the course too; the director only reads them. The course comes from the URL and is scoped to the
# active university (A3), so a course or section of the other university is a 404.
class SectionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :section, through: :course

  def index
    @sections = @sections.eager_load(:term).order("terms.starts_on DESC", :number)
  end

  # The section overview. Its staff, the coordinator, the administrativo and the director see the summary, the
  # attendance list and (if they can read the grades) the grades; a student sees only their own grades and
  # attendance, and the course material. Tabs: ?tab=asistencia, ?tab=notas.
  def show
    @stats = SectionStatsService.new(@section)
    @student_view = !can?(:read_attendance_sheet, @section)
    @tab = %w[asistencia notas].include?(params[:tab]) && !@student_view ? params[:tab] : "resumen"
    @tab = "resumen" if @tab == "notas" && !can?(:read_gradebook, @section)
    @materials = @course.materials.with_attached_file.order(:title)
    # Profesores, ayudantes and students go from the course straight to their section, so their way back is the list.
    @course_overview = catalog_view? || @course.course_coordinators.exists?(user: current_user)
  end

  def new
  end

  def edit
  end

  def create
    @section.university = @course.university

    if @section.save
      redirect_to course_section_path(@course, @section), notice: "La sección fue creada."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @section.update(section_params)
      redirect_to course_section_path(@course, @section), notice: "La sección fue actualizada.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @section.destroy
      redirect_to course_sections_path(@course), notice: "La sección fue eliminada.", status: :see_other
    else
      redirect_to course_section_path(@course, @section), status: :see_other,
        alert: "No se puede eliminar la sección #{@section.errors.full_messages.to_sentence}. " \
               "Para mantener la trazabilidad, solo se eliminan secciones sin profesor, ayudantes, alumnos, " \
               "evaluaciones, asistencia ni avisos."
    end
  end

  private

  # The course comes from the URL and the university from the active tenant, never from the form.
  def section_params
    params.expect(section: [ :term_id, :number ])
  end
end
