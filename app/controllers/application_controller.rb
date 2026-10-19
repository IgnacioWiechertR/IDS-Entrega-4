class ApplicationController < ActionController::Base
  # Obliga a iniciar sesión para entrar a las páginas internas
  before_action :authenticate_user!
  
  # Llama a este método si estamos en un controlador de Devise (ej: Sign Up)
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  # Permite que Devise guarde los campos extra al registrarse
  def configure_permitted_parameters
    # Agregamos :name, :rut y :role para que Devise los guarde en la BD
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :rut, :role])
  end

  # Redirección según rol (como lo vimos antes)
  def after_sign_in_path_for(resource)
    case resource.role&.to_sym
    when :director
      dashboard_path
    when :administrativo
      accounts_path
    when :profesor, :ayudante, :alumno
      courses_path
    else
      root_path
    end
  end
end