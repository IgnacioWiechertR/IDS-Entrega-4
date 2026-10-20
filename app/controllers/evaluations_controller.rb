class EvaluationsController < ApplicationController
  load_and_authorize_resource
  before_action :set_evaluation, only: %i[ show edit update destroy ]

  # GET /evaluations
  def index
    @evaluations = Evaluation.all
  end

  # GET /evaluations/1
  def show
  end

  # GET /evaluations/new
  def new
    @evaluation = Evaluation.new
  end

  # GET /evaluations/1/edit
  def edit
  end

  # POST /evaluations
  def create
    @evaluation = Evaluation.new(evaluation_params)

    if @evaluation.save
      redirect_to @evaluation, notice: "Evaluation was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /evaluations/1
  def update
    if @evaluation.update(evaluation_params)
      redirect_to @evaluation, notice: "Evaluation was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /evaluations/1
  def destroy
    @evaluation.destroy!
    redirect_to evaluations_path, notice: "Evaluation was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_evaluation
      @evaluation = Evaluation.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def evaluation_params
      params.expect(evaluation: [ :section_id, :name, :weight, :due_on, :rubric ])
    end
end
