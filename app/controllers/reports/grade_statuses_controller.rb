module Reports
  class GradeStatusesController < ApplicationController
    def show
      authorize! :read_grade_statuses, :reports

      @university = current_university
      @terms = Term.where(university_id: @university&.id).order(starts_on: :desc)
      @selected_term_id = params[:term_id].presence
      @rows = SectionGradeStatusSummaryService.call(
        university: @university,
        term_id: @selected_term_id
      )
    end
  end
end
