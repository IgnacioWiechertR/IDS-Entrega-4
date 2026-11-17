# Director's dashboard: the end-of-term summary of the active university (switched with the selector in the top
# bar) and both universities side by side, each one computed inside its own university (D1), and the accounts of
# the active university by role (D7).
class DashboardController < ApplicationController
  def index
    authorize! :read, :dashboard

    @summaries = University.order(:name).map { |university| UniversitySummaryService.new(university) }
    @summary = @summaries.find { |summary| summary.university == current_university }

    # D7: the accounts of the university picked with the selector (A3), by role.
    @role_counts = User.count_by_role(current_university)
  end
end
