class AccountsController < ApplicationController
  before_action :authenticate_user!
  load_and_authorize_resource class: 'User' # Validación de permisos con CanCanCan

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    
    # Lógica de negocio: Si quien crea es administrativo
    if current_user.administrativo?
      # La cuenta queda en la misma universidad del administrativo
      @user.university_id = current_user.university_id
      
      # El rol por defecto es alumno si no se seleccionó otro permitido
      @user.role = :alumno if @user.role.blank?
    end

    # Se usa una contraseña temporal segura generada aleatoriamente
    @user.password = Devise.friendly_token.first(8)

    if @user.save
      # Se envía correo para que el nuevo usuario recupere/cambie su contraseña
      @user.send_reset_password_instructions
      redirect_to accounts_path, notice: "Cuenta creada exitosamente para #{@user.name}."
    else
      # status: :unprocessable_entity es requerido en Rails 7+ con Turbo para mostrar errores
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :rut, :email, :role)
  end
end