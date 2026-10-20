# C1: the ayudante of a section enters the preliminary grades of one of its evaluations, and each profesor of
# the section is notified to review them.
class GradeSheetsController < ApplicationController
  before_action :set_evaluation

  def edit
    load_sheet
  end

  def update
    result = GradeEntryService.new(evaluation: @evaluation, author: current_user, entries: entry_params).call

    if !result.success?
      @errors = result.errors
      @entries = entry_params
      load_sheet
      render :edit, status: :unprocessable_content
    elsif result.saved_count.zero?
      redirect_to edit_section_evaluation_grade_sheet_path(@section, @evaluation), alert: "No ingresaste ninguna nota.",
        status: :see_other
    else
      GradeSubmissionNotificationJob.perform_later(@evaluation, result.saved_count)
      redirect_to section_evaluations_path(@section), notice: submitted_message(result.saved_count), status: :see_other
    end
  end

  private

  # The section is scoped by the active university (A3), so one from the other university is a 404.
  def set_evaluation
    @section = Section.find(params.expect(:section_id))
    @evaluation = @section.evaluations.find(params.expect(:evaluation_id))
    authorize! :enter_grades, @evaluation
  end

  def load_sheet
    @students = @section.active_students
    @grades = @evaluation.grades.index_by(&:student_id)
    @errors ||= {}
    @entries ||= {}
  end

  # entries[student_id][score|feedback|points]
  def entry_params
    entries = params.fetch(:entries, {})
    entries.keys.index_with { |student_id| entries.fetch(student_id).permit(:score, :feedback, :points).to_h }
  end

  def submitted_message(count)
    count == 1 ? "1 nota enviada a revisión." : "#{count} notas enviadas a revisión."
  end
end
