# C2: the profesor of the section sees the pending grades of an evaluation.
# C5: "Aceptar notas" publishes them all at once and notifies each student.
# C6: "Rechazar notas" sends them back to the ayudante with a mandatory comment and notifies the ayudante.
class GradeReviewsController < ApplicationController
  ERRORS = {
    none_pending: "No hay notas pendientes de revisión.",
    out_of_range: "Hay notas fuera de 1,0–7,0: no se publicó ninguna."
  }.freeze

  before_action :set_evaluation

  def show
    load_review
  end

  def approve
    result = GradeApprovalService.new(evaluation: @evaluation, reviewer: current_user).call

    if result.success?
      GradesPublishedNotificationJob.perform_later(@evaluation, result.student_ids)
      redirect_to review_path, notice: approved_message(result.count), status: :see_other
    else
      redirect_to review_path, alert: ERRORS.fetch(result.error), status: :see_other
    end
  end

  def reject
    comment = params[:rejection_comment].to_s.strip
    result = GradeRejectionService.new(evaluation: @evaluation, reviewer: current_user, comment: comment).call

    if result.success?
      GradesRejectedNotificationJob.perform_later(@evaluation, result.assistant_ids, result.count, comment)
      redirect_to review_path, notice: rejected_message(result.count), status: :see_other
    elsif result.error == :comment_required
      @comment_error = "Debes escribir un comentario para rechazar las notas."
      load_review
      render :show, status: :unprocessable_content
    else
      redirect_to review_path, alert: ERRORS.fetch(result.error), status: :see_other
    end
  end

  private

  # The section is scoped by the active university (A3), so one from the other university is a 404.
  def set_evaluation
    @section = Section.find(params.expect(:section_id))
    @evaluation = @section.evaluations.find(params.expect(:evaluation_id))
    authorize! :review_grades, @evaluation
  end

  def load_review
    @pending = @evaluation.grades.pendiente.includes(:student, :entered_by).joins(:student)
      .order("users.last_name", "users.first_name")
    @rejected_count = @evaluation.grades.rechazada.count
    @published_count = @evaluation.grades.publicada.count
  end

  def review_path = section_evaluation_grade_review_path(@section, @evaluation)

  def approved_message(count) = count == 1 ? "1 nota aprobada y publicada." : "#{count} notas aprobadas y publicadas."

  def rejected_message(count)
    count == 1 ? "1 nota rechazada. Se avisó al ayudante." : "#{count} notas rechazadas. Se avisó al ayudante."
  end
end
