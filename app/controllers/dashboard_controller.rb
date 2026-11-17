# Director's dashboard: the end-of-term summary of the active university (switched with the selector in the top
# bar) and both universities side by side, each one computed inside its own university (D1), and the accounts of
# the active university by role (D7).
# D2: the summary of the active university can be filtered by term, faculty and course. The comparison keeps the
# current term of each university, since terms, faculties and courses belong to one university.
class DashboardController < ApplicationController
  def index
    authorize! :read, :dashboard

    @filters = params.permit(:term_id, :faculty_id, :course_id).to_h.symbolize_keys.compact_blank
    @summary = UniversitySummaryService.new(current_university, **@filters) if current_university
    @summaries = University.order(:name).map do |university|
      reuse = university == current_university && @filters.empty?
      reuse ? @summary : UniversitySummaryService.new(university)
    end

    @terms = Term.order(starts_on: :desc, id: :desc)
    @faculties = Faculty.order(:name)
    @courses = Course.order(:code)

    # D7: the accounts of the university picked with the selector (A3), by role.
    @role_counts = User.count_by_role(current_university)
  end
end
