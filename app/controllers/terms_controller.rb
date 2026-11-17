# The terms of the active university: the administrativo creates, edits and deletes them; the director only lists them.
class TermsController < ApplicationController
  load_and_authorize_resource

  # GET /terms
  def index
    @terms = @terms.order(starts_on: :desc)
    @section_counts = Section.where(term_id: @terms.map(&:id)).group(:term_id).count
  end

  # GET /terms/new
  def new
  end

  # GET /terms/1/edit
  def edit
  end

  # POST /terms. The university comes from the active tenant, never from the form.
  def create
    if @term.save_marking_current
      redirect_to terms_path, notice: "El período #{@term.name} fue creado.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /terms/1
  def update
    @term.assign_attributes(term_params)
    if @term.save_marking_current
      redirect_to terms_path, notice: "El período #{@term.name} fue actualizado.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /terms/1: only a term without sections or coordinators.
  def destroy
    if @term.destroy
      redirect_to terms_path, notice: "El período #{@term.name} fue eliminado.", status: :see_other
    else
      redirect_to terms_path, status: :see_other,
        alert: "No se puede eliminar el período #{@term.name} #{@term.errors.full_messages.to_sentence}. " \
               "Para mantener la trazabilidad, solo se eliminan períodos sin secciones ni coordinadores."
    end
  end

  private

  def term_params
    params.expect(term: [ :name, :starts_on, :ends_on, :current ])
  end
end
