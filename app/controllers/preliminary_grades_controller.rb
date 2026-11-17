# C4: the ayudante of a section deletes a preliminary grade (pending or rejected) entered by mistake, from the
# grade sheet. An official grade is never deleted (DOMAIN §3; Grade also refuses it).
class PreliminaryGradesController < ApplicationController
  def destroy
    # The section is scoped by the active university (A3): one from the other university is a 404, and so is a
    # grade of another evaluation.
    section = Section.find(params.expect(:section_id))
    evaluation = section.evaluations.find(params.expect(:evaluation_id))
    authorize! :enter_grades, evaluation
    grade = evaluation.grades.includes(:student).find(params.expect(:id))
    sheet = edit_section_evaluation_grade_sheet_path(section, evaluation)

    if grade.destroy
      redirect_to sheet, notice: "Se eliminó la nota de #{grade.student.name}.", status: :see_other
    else
      redirect_to sheet, alert: "Una nota oficial no se puede eliminar.", status: :see_other
    end
  end
end
