require "csv"

class AccountsController < ApplicationController
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
        condition += " OR regexp_replace(rut, '[.[:space:]-]', '', 'g') ILIKE :rut"
      end

      @accounts = @accounts.where(
        condition,
        name: name_pattern,
        rut: rut_pattern
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

  private

  def account_params
    params.expect(account: [ :first_name, :last_name, :rut, :email, :role ])
  end
end
