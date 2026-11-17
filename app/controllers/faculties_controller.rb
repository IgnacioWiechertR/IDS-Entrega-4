# The faculties of the active university: the administrativo creates, edits and deletes them; the director only
# lists them. Every course belongs to one.
class FacultiesController < ApplicationController
  load_and_authorize_resource

  # GET /faculties
  def index
    @faculties = @faculties.order(:name)
    @course_counts = Course.where(faculty_id: @faculties.map(&:id)).group(:faculty_id).count
  end

  # GET /faculties/new
  def new
  end

  # GET /faculties/1/edit
  def edit
  end

  # POST /faculties. The university comes from the active tenant, never from the form.
  def create
    if @faculty.save
      redirect_to faculties_path, notice: "La facultad #{@faculty.name} fue creada.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /faculties/1
  def update
    if @faculty.update(faculty_params)
      redirect_to faculties_path, notice: "La facultad #{@faculty.name} fue actualizada.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /faculties/1: only a faculty without courses.
  def destroy
    if @faculty.destroy
      redirect_to faculties_path, notice: "La facultad #{@faculty.name} fue eliminada.", status: :see_other
    else
      redirect_to faculties_path, status: :see_other,
        alert: "No se puede eliminar la facultad #{@faculty.name} #{@faculty.errors.full_messages.to_sentence}. " \
               "Primero mueve o elimina sus cursos."
    end
  end

  private

  def faculty_params
    params.expect(faculty: [ :name ])
  end
end
