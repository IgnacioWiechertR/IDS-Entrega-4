class SectionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :section, through: :course

  def index
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
      redirect_to course_section_path(@course, @section), notice: "La sección fue creada exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @section.update(section_params)
      redirect_to course_section_path(@course, @section), notice: "La sección fue actualizada exitosamente.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @section.destroy
      redirect_to course_sections_path(@course), notice: "La sección fue eliminada exitosamente.", status: :see_other
    else
      redirect_to course_sections_path(@course), alert: "No se puede eliminar la sección porque tiene evaluaciones o asistencia registrada."
    end
  end

  private
    def section_params
      params.expect(section: [ :term_id, :number ])
    end
end
