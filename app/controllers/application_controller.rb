class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :authenticate_user!

  # Every action must call authorize! (or load_and_authorize_resource).
  check_authorization unless: :devise_controller?

  helper_method :home_path_for

  rescue_from CanCan::AccessDenied do |exception|
    Rails.logger.warn(
      "[authz] acceso denegado user_id=#{current_user&.id} role=#{current_user&.role} " \
      "action=#{exception.action} subject=#{authorization_subject(exception.subject)} path=#{request.fullpath}"
    )
    redirect_to home_path_for(current_user), alert: t("authorization.denied")
  end

  private

  def authorization_subject(subject)
    case subject
    when Class, Symbol then subject.to_s
    else "#{subject.class.name}##{subject.try(:id) || 'nuevo'}"
    end
  end

  # Each role lands on its own panel after signing in.
  def home_path_for(user)
    if user.director?
      dashboard_path
    elsif user.administrativo?
      accounts_path
    else
      courses_path
    end
  end

  def after_sign_in_path_for(user)
    stored_location_for(user) || home_path_for(user)
  end
end
