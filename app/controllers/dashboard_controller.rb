class DashboardController < ApplicationController
  def index
    authorize! :read, :dashboard
  end
end
