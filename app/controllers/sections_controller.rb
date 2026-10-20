# Sections of a course (A18): the administrativo creates, edits and deletes them in their university; the
# coordinator of the course too; the director only reads them. The course comes from the URL and is scoped to the
# active university (A3), so a course or section of the other university is a 404.
class SectionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :section, through: :course

  def index
    @sections = @sections.eager_load(:term).order("terms.starts_on DESC", :number)
  end

  def show
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
