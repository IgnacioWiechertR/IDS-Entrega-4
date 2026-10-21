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
    @total_pages = [(@total_accounts.to_f / per_page).ceil, 1].max
    @page = params[:page].to_s.to_i.clamp(1, @total_pages)

    @accounts = @accounts.order(:last_name, :first_name, :id)
                         .limit(per_page)
                         .offset((@page - 1) * per_page)
  end
end