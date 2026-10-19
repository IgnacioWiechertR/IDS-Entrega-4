class CourseCoordinatorsController < ApplicationController
  before_action :set_course_coordinator, only: %i[ show edit update destroy ]

  # GET /course_coordinators
  def index
    @course_coordinators = CourseCoordinator.all
  end

  # GET /course_coordinators/1
  def show
  end

  # GET /course_coordinators/new
  def new
    @course_coordinator = CourseCoordinator.new
  end

  # GET /course_coordinators/1/edit
  def edit
  end

  # POST /course_coordinators
  def create
    @course_coordinator = CourseCoordinator.new(course_coordinator_params)

    if @course_coordinator.save
      redirect_to @course_coordinator, notice: "Course coordinator was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /course_coordinators/1
  def update
    if @course_coordinator.update(course_coordinator_params)
      redirect_to @course_coordinator, notice: "Course coordinator was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /course_coordinators/1
  def destroy
    @course_coordinator.destroy!
    redirect_to course_coordinators_path, notice: "Course coordinator was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_course_coordinator
      @course_coordinator = CourseCoordinator.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def course_coordinator_params
      params.expect(course_coordinator: [ :course_id, :term_id, :user_id, :assigned_by_id ])
    end
end
