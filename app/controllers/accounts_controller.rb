class AccountsController < ApplicationController
  def index
    authorize! :index, :accounts
  end

  # A4: one account at a time, in the university of the administrativo. The role starts as alumno.
  def new
    @account = User.new(role: "alumno", university: current_user.university)
    authorize! :create_account, @account
  end

  # The system generates a temporary password and shows it only on this response: it is not stored in the flash
  # or the session, and the page is not cached, so it cannot be seen again.
  def create
    @account = User.new(account_params)
    @account.university = current_user.university
    @account.active = true
    @account.password = @temporary_password = SecureRandom.alphanumeric(12)
    authorize! :create_account, @account

    if @account.save
      no_store
      render :created, status: :created
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def account_params
    params.expect(account: [ :first_name, :last_name, :rut, :email, :role ])
  end
end
