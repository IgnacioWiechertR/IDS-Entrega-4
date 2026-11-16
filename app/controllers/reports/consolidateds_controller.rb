module Reports
  class ConsolidatedsController < ApplicationController
    def show
      authorize! :read_consolidated, :reports

      @university = current_university
      @terms = Term.where(university_id: @university&.id).order(starts_on: :desc)
      @courses = Course.where(university_id: @university&.id).order(:code)
      @selected_term_id = params[:term_id].presence
      @selected_course_id = params[:course_id].presence

      @rows = ConsolidatedReportService.call(
        university: @university,
        term_id: @selected_term_id,
        course_id: @selected_course_id
      )

      @sections_with_evaluations = @rows.select { |r| r.has_evaluations && r.average_grade.present? }

      respond_to do |format|
        format.html
        format.csv do
          filename = "reporte_consolidado_#{@university.slug}_#{Date.current.iso8601}.csv"
          send_data ConsolidatedReportService.to_csv(@rows),
                    filename:,
                    type: "text/csv; charset=utf-8",
                    disposition: "attachment"
        end
      end
    end
  end
end
