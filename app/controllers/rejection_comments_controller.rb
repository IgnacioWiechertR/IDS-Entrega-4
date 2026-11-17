# C8: from the grade review, the profesor who rejected the grades of an evaluation edits the rejection comment.
# C9: or deletes it, which withdraws the rejection (its grades go back to pending review).
# :id is one grade of that rejection; the services change every grade of it.
class RejectionCommentsController < ApplicationController
  before_action :set_grade

  def update
    authorize! :edit_rejection_comment, @grade
    result = RejectionCommentUpdateService.new(grade: @grade, comment: params[:rejection_comment]).call

    if result.success?
      redirect_to review_path, notice: "Comentario actualizado.", status: :see_other
    else
      redirect_to review_path, alert: "El comentario no puede quedar vacío.", status: :see_other
    end
  end

  def destroy
    authorize! :delete_rejection_comment, @grade
    count = RejectionCommentRemovalService.new(grade: @grade).call

    grades = count == 1 ? "1 nota volvió" : "#{count} notas volvieron"
    redirect_to review_path, notice: "Se eliminó el comentario: #{grades} a pendiente de revisión.", status: :see_other
  end

  private

  # The section is scoped by the active university (A3): one from the other university is a 404, and so is a
  # grade of another evaluation.
  def set_grade
    @section = Section.find(params.expect(:section_id))
    @evaluation = @section.evaluations.find(params.expect(:evaluation_id))
    @grade = @evaluation.grades.find(params.expect(:id))
  end

  def review_path = section_evaluation_grade_review_path(@section, @evaluation)
end
