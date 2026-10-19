class GradesController < ApplicationController
  before_action :set_grade, only: %i[ show edit update destroy ]

  # GET /grades
  def index
    @grades = Grade.all
  end

  # GET /grades/1
  def show
  end

  # GET /grades/new
  def new
    @grade = Grade.new
  end

  # GET /grades/1/edit
  def edit
  end

  # POST /grades
  def create
    @grade = Grade.new(grade_params)

    if @grade.save
      redirect_to @grade, notice: "Grade was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /grades/1
  def update
    if @grade.update(grade_params)
      redirect_to @grade, notice: "Grade was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /grades/1
  def destroy
    @grade.destroy!
    redirect_to grades_path, notice: "Grade was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_grade
      @grade = Grade.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def grade_params
      params.expect(grade: [ :evaluation_id, :student_id, :score, :status, :feedback, :rejection_comment, :entered_by_id, :reviewed_by_id ])
    end
end
