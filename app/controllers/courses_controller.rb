class CoursesController < ApplicationController
  load_and_authorize_resource
  before_action :set_course, only: %i[ show edit update destroy ]

  # GET /courses ("Mis cursos"): load_and_authorize_resource loads only the courses the user can read.
  def index
  end

  # GET /courses/1
  def show
  end

  # GET /courses/new
  def new
    @course = Course.new
  end

  # GET /courses/1/edit
  def edit
  end

  # POST /courses
  def create
    @course = Course.new(course_params)

    if @course.save
      redirect_to @course, notice: "Course was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /courses/1
  def update
    if @course.update(course_params)
      redirect_to @course, notice: "Course was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /courses/1
  def destroy
    @course.destroy!
    redirect_to courses_path, notice: "Course was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course
      @course = Course.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def course_params
      params.expect(course: [ :university_id, :faculty_id, :code, :name ])
    end
end
