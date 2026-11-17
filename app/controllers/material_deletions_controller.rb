class MaterialDeletionsController < ApplicationController
  before_action :prevent_shared_caching
  before_action :set_readable_course
  before_action :set_owned_material, only: %i[ show destroy ]

  def index
    authorize! :index, :material_deletions
    @materials = @course.materials.accessible_by(current_ability, :destroy)
      .with_attached_file.distinct.order(created_at: :desc, id: :desc)
  end

  # A GET only asks for confirmation; it never deletes a record or a file.
  def show
  end

  def destroy
    unless params[:confirmation] == "eliminar"
      redirect_to course_material_deletion_path(@course, @material),
        alert: "Confirma la eliminación para continuar.", status: :see_other
      return
    end

    if @material.destroy
      redirect_to course_material_deletions_path(@course),
        notice: "Material eliminado correctamente.", status: :see_other
    else
      redirect_to course_material_deletions_path(@course),
        alert: "No se pudo eliminar el material. Vuelve a intentarlo.", status: :see_other
    end
  end

  private

  def set_readable_course
    @course = Course.find(params.expect(:course_id))
    authorize! :read, @course
  end

  def set_owned_material
    @material = @course.materials.with_attached_file.find(params.expect(:id))
    authorize! :destroy, @material
  end

  def prevent_shared_caching
    response.headers["Cache-Control"] = "private, no-store"
  end
end
