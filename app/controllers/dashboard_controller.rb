# Director's end-of-term dashboard (D1): the summary of the active university (switched with the selector in
# the top bar) and both universities side by side, each one computed inside its own university.
class DashboardController < ApplicationController
  def index
    authorize! :read, :dashboard

    @summaries = University.order(:name).map { |university| UniversitySummaryService.new(university) }
    @summary = @summaries.find { |summary| summary.university == current_university }
  end
end
