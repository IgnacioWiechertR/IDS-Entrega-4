class DashboardController < ApplicationController
  def index
    authorize! :read, :dashboard

    # D7: the accounts of the university picked with the selector (A3), by role.
    @role_counts = User.count_by_role(current_university)
  end
end
