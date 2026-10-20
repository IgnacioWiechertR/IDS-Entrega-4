class AccountsController < ApplicationController
  # Le decimos a CanCanCan que use el modelo User para los recursos de este controlador
  load_and_authorize_resource class: 'User'

  def index
    @users = User.accessible_by(current_ability)
  end

  # ... resto de tus métodos actuales ...
end