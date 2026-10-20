# C11: the profesor and the ayudantes of a section see all its grades with their status.
# The section is looked up only among the ones the user takes part in, so any other section (of their university,
# or of the other one) is a 404, as the card asks.
class GradebooksController < ApplicationController
  def show
    @section = Section.accessible_by(current_ability, :read_gradebook).find(params.expect(:section_id))
    authorize! :read_gradebook, @section

    @evaluations = @section.evaluations.order(:due_on, :id).to_a
    @students = @section.active_students.to_a
    @grades = Grade.where(evaluation: @evaluations).index_by { |grade| [ grade.student_id, grade.evaluation_id ] }
  end
end
