class EnrollmentsController < ApplicationController
  load_and_authorize_resource
  before_action :set_enrollment, only: %i[ show edit update destroy ]

  # GET /enrollments
  def index
    @enrollments = Enrollment.all
  end

  # GET /enrollments/1
  def show
  end

  # GET /enrollments/new
  def new
    @enrollment = Enrollment.new
  end

  # GET /enrollments/1/edit
  def edit
  end

  # POST /enrollments
  def create
    @enrollment = Enrollment.new(enrollment_params)

    if @enrollment.save
      redirect_to @enrollment, notice: "Enrollment was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /enrollments/1
  def update
    if @enrollment.update(enrollment_params)
      redirect_to @enrollment, notice: "Enrollment was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /enrollments/1
  def destroy
    @enrollment.destroy!
    redirect_to enrollments_path, notice: "Enrollment was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_enrollment
      @enrollment = Enrollment.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def enrollment_params
      params.expect(enrollment: [ :section_id, :student_id, :active ])
    end
end
