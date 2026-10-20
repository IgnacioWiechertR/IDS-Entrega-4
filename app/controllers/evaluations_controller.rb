# C13: the profesor or the ayudante of a section creates its evaluations.
class EvaluationsController < ApplicationController
  before_action :set_section

  def index
    @evaluations = @section.evaluations.order(:due_on, :id)
  end

  def new
    @evaluation = @section.evaluations.build
  end

  def create
    @evaluation = @section.evaluations.build(evaluation_params)

    if @evaluation.save
      redirect_to section_evaluations_path(@section), notice: "Evaluación creada.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # The section is scoped by the active university (A3), so one from the other university is a 404.
  # Only the teaching staff of this section may work with its evaluations.
  def set_section
    @section = Section.find(params.expect(:section_id))
    authorize! :create, Evaluation.new(section: @section)
  end

  def evaluation_params
    params.expect(evaluation: [ :name, :weight, :due_on, :rubric ])
  end
end
