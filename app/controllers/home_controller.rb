class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  def index
    redirect_to home_path_for(current_user) if user_signed_in?
  end
end
