require "csv"

class AccountsController < ApplicationController
  before_action :set_account, only: %i[edit update destroy reactivate]

  def index
    authorize! :index, :accounts

    @university = current_university
    @query = params[:q].to_s.strip
    @role = params[:role].to_s
    @role = "" unless User.roles.key?(@role)

    @accounts =
      if @university
        User.where(university_id: @university.id)
      else
        User.none
      end

    if @query.present?
      name_pattern = "%#{User.sanitize_sql_like(@query)}%"
      normalized_rut = @query.delete(".-").gsub(/\s+/, "")
      rut_pattern = "%#{User.sanitize_sql_like(normalized_rut)}%"

      condition = "concat_ws(' ', first_name, last_name) ILIKE :name"

      if normalized_rut.present?
        condition += " OR regexp_replace(rut, :rut_format, '', 'g') ILIKE :rut"
      end

      @accounts = @accounts.where(
        condition,
        name: name_pattern,
        rut: rut_pattern,
        rut_format: "[.[:space:]-]"
      )
    end

    @accounts = @accounts.where(role: @role) if @role.present?
    per_page = 10
    @total_accounts = @accounts.count
    @total_pages = [ (@total_accounts.to_f / per_page).ceil, 1 ].max
    @page = params[:page].to_s.to_i.clamp(1, @total_pages)

    @accounts = @accounts.order(:last_name, :first_name, :id)
                         .limit(per_page)
                         .offset((@page - 1) * per_page)
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

  def import_form
    authorize! :import, :accounts
  end

  def import_csv
    authorize! :import, :accounts
    no_store

    @result = AccountCsvImporter.new(actor: current_user)
                               .call(params[:file])

    render :import_result
  rescue AccountCsvImporter::InvalidFile => error
    @import_error = error.message
    render :import_form, status: :unprocessable_content
  end

  def sample_csv
    authorize! :import, :accounts

    content = CSV.generate do |csv|
      csv << %w[nombre rut correo rol]
      csv << [ "Ana Pérez", "12.345.678-5", "ana.perez@example.com", "alumno" ]
    end

    send_data content,
              filename: "ejemplo_cuentas.csv",
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  # A17: cambia el rol de una cuenta de la universidad activa de inmediato.
  def update_role
    authorize! :index, :accounts
    @university = current_university
    @account = User.where(university_id: @university&.id).find(params[:id])

    authorize! :change_role, @account

    previous_role = @account.role
    new_role = role_params[:role].to_s

    if previous_role == new_role
      redirect_to accounts_path(q: params[:q], role: params[:role], page: params[:page]),
                  notice: "La cuenta ya tiene el rol seleccionado."
      return
    end

    @account.role = new_role
    authorize! :change_role, @account

    if @account.save
      redirect_to accounts_path(q: params[:q], role: params[:role], page: params[:page]),
                  notice: "Rol de #{@account.name} actualizado a #{@account.role_name}."
    else
      redirect_to accounts_path(q: params[:q], role: params[:role], page: params[:page]),
                  alert: @account.errors.full_messages.to_sentence
    end
  end

  # Personal data of an account. The role changes from the list (A17) and the university never changes.
  def edit
    authorize! :update_account, @account
  end

  def update
    authorize! :update_account, @account

    if @account.update(edit_account_params)
      redirect_to after_management_path, notice: "Datos de #{@account.name} actualizados.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Deleting an account deactivates it: the person can no longer sign in (User#active_for_authentication?, also
  # on the session it had open) and the row stays, so its grades, attendance and assignments keep their author.
  # It writes the column directly: revoking access must not depend on the rest of the record being valid.
  def destroy
    authorize! :destroy_account, @account

    if @account.deactivated?
      redirect_to accounts_path(**list_filters), notice: "La cuenta de #{@account.name} ya estaba eliminada.",
                                                 status: :see_other
      return
    end

    @account.update_columns(active: false, updated_at: Time.current)
    redirect_to accounts_path(**list_filters), status: :see_other,
      notice: "La cuenta de #{@account.name} fue eliminada: ya no puede iniciar sesión. Su historial se conserva."
  end

  # Undoes a deletion by mistake.
  def reactivate
    authorize! :reactivate_account, @account

    @account.update_columns(active: true, updated_at: Time.current)
    redirect_to accounts_path(**list_filters), notice: "La cuenta de #{@account.name} fue reactivada.",
                                               status: :see_other
  end

  private

  # Accounts of the active university, so one of the other university is a 404 (A3). The director has no
  # university and reaches only its own account outside of it.
  def set_account
    @account =
      if current_user.director? && params[:id].to_s == current_user.id.to_s
        User.find(current_user.id) # a separate copy, so a failed edit does not show in the top bar
      else
        User.where(university_id: current_university&.id).find(params.expect(:id))
      end
  end

  # The list keeps its search, role filter and page after editing.
  def list_filters
    { q: params[:q].presence, role: params[:role].presence, page: params[:page].presence }.compact
  end

  def after_management_path
    @account == current_user ? edit_account_path(@account) : accounts_path(**list_filters)
  end

  def account_params
    params.expect(account: [ :first_name, :last_name, :rut, :email, :role ])
  end

  def edit_account_params
    params.expect(account: [ :first_name, :last_name, :rut, :email ])
  end

  def role_params
    params.expect(account: [ :role ])
  end
end
