class SectionsController < ApplicationController
  # CanCanCan carga automáticamente @course (si viene en la URL) y @section (para show, edit, update, destroy)
  # También se encarga de llamar a authorize! para cada acción.
  load_and_authorize_resource :course, optional: true
  load_and_authorize_resource :section, through: :course, shallow: true

  # GET /courses/:course_id/sections o GET /sections
  def index
    if @course
      @sections = @course.sections.accessible_by(current_ability)
    else
      @sections = Section.accessible_by(current_ability)
    end
  end

  # GET /courses/:course_id/sections/1 o GET /sections/1
  def show
  end

  # GET /courses/:course_id/sections/new o GET /sections/new
  def new
    # @section ya viene instanciado por load_and_authorize_resource
  end

  # GET /courses/:course_id/sections/1/edit o GET /sections/1/edit
  def edit
  end

  # POST /courses/:course_id/sections o POST /sections
  def create
    # @section ya viene inicializado con section_params por load_and_authorize_resource
    if @section.save
      redirect_to (@course ? course_section_path(@course, @section) : section_path(@section)), notice: "La sección fue creada exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /courses/:course_id/sections/1 o PATCH/PUT /sections/1
  def update
    if @section.update(section_params)
      redirect_to (@course ? course_section_path(@course, @section) : section_path(@section)), notice: "La sección fue actualizada exitosamente.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /courses/:course_id/sections/1 o DELETE /sections/1
  def destroy
    @section.destroy!
    redirect_to (@course ? course_sections_path(@course) : sections_path), notice: "La sección fue eliminada exitosamente.", status: :see_other
  end

  private

    def section_params
      params.expect(section: [ :course_id, :university_id, :term_id, :number ])
    end
end