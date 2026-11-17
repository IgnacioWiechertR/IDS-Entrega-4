# C8: from the grade review, the profesor who rejected the grades of an evaluation edits the rejection comment.
# :id is one grade of that rejection; RejectionCommentUpdateService changes every grade of it.
class RejectionCommentsController < ApplicationController
  def update
    # The section is scoped by the active university (A3): one from the other university is a 404, and so is a
    # grade of another evaluation.
    section = Section.find(params.expect(:section_id))
    evaluation = section.evaluations.find(params.expect(:evaluation_id))
    grade = evaluation.grades.find(params.expect(:id))
    authorize! :edit_rejection_comment, grade

    result = RejectionCommentUpdateService.new(grade: grade, comment: params[:rejection_comment]).call
    review = section_evaluation_grade_review_path(section, evaluation)

    if result.success?
      redirect_to review, notice: "Comentario actualizado.", status: :see_other
    else
      redirect_to review, alert: "El comentario no puede quedar vacío.", status: :see_other
    end
  end
end
