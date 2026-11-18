class HomeController < ApplicationController
  skip_before_action :authenticate_user!
  skip_authorization_check

  # The root shows nothing of the app without a session: it only sends each visitor where they belong.
  def index
    redirect_to user_signed_in? ? home_path_for(current_user) : new_user_session_path
  end
end
