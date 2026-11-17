# C13: the profesor or the ayudante of a section creates its evaluations. The director only lists them.
class EvaluationsController < ApplicationController
  before_action :set_section
  before_action :authorize_creation, only: %i[new create]

  def index
    authorize! :read, Evaluation.new(section: @section)
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
  def set_section
    @section = Section.find(params.expect(:section_id))
  end

  # Only the teaching staff of this section creates its evaluations.
  def authorize_creation
    authorize! :create, Evaluation.new(section: @section)
  end

  def evaluation_params
    params.expect(evaluation: [ :name, :weight, :due_on, :rubric, :max_points ])
  end
end
