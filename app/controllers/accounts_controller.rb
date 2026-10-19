class AccountsController < ApplicationController
  def index
    authorize! :index, :accounts
  end
end
