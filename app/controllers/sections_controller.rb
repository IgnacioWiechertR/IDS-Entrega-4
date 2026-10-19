class SectionsController < ApplicationController
  before_action :set_course
  before_action :set_section, only: %i[ show edit update destroy ]

  # GET /courses/:course_id/sections
  def index
    @sections = @course.sections
  end

  # GET /courses/:course_id/sections/1
  def show
  end

  # GET /courses/:course_id/sections/new
  def new
    @section = @course.sections.build
  end

  # GET /courses/:course_id/sections/1/edit
  def edit
  end

  # POST /courses/:course_id/sections
  def create
    @section = @course.sections.build(section_params)

    if @section.save
      redirect_to course_section_path(@course, @section), notice: "La sección fue creada exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /courses/:course_id/sections/1
  def update
    if @section.update(section_params)
      redirect_to course_section_path(@course, @section), notice: "La sección fue actualizada exitosamente.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /courses/:course_id/sections/1
  def destroy
    @section.destroy!
    redirect_to course_sections_path(@course), notice: "La sección fue eliminada exitosamente.", status: :see_other
  end

  private
    def set_course
      @course = Course.find(params[:course_id])
      authorize! :read, @course
    end

    def set_section
      @section = @course.sections.find(params.expect(:id))
    end

    def section_params
      params.expect(section: [ :university_id, :term_id, :number ])
    end
end
