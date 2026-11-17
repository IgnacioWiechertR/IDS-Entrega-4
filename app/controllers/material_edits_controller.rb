class MaterialEditsController < ApplicationController
  before_action :prevent_shared_caching
  before_action :set_readable_course
  before_action :set_owned_material, only: %i[ edit update ]

  def index
    authorize! :index, :material_edits
    @materials = @course.materials.accessible_by(current_ability, :update)
      .with_attached_file.distinct.order(created_at: :desc, id: :desc)
  end

  def edit
  end

  def update
    attributes = params.expect(material: [ :title, :file ])
    @material.title = attributes[:title] if attributes.key?(:title)
    upload = attributes[:file]

    if upload.present? && !upload.is_a?(ActionDispatch::Http::UploadedFile)
      @material.valid?
      @material.errors.add(:file, "debe seleccionarse desde tu equipo")
    else
      # Assignment defers persistence until save: invalid submissions retain the old attachment.
      @material.file = upload if upload.is_a?(ActionDispatch::Http::UploadedFile)
      if @material.save
        redirect_to edit_course_material_edit_path(@course, @material),
          notice: "Material actualizado correctamente.", status: :see_other
        return
      end
    end

    render :edit, status: :unprocessable_content
  rescue MaterialStorageService::UniversityNotConfigured
    @material.errors.add(:file, "no se pudo guardar porque el almacenamiento de esta universidad no está configurado")
    render :edit, status: :unprocessable_content
  end

  private

  def set_readable_course
    @course = Course.find(params.expect(:course_id))
    authorize! :read, @course
  end

  def set_owned_material
    @material = @course.materials.with_attached_file.find(params.expect(:id))
    authorize! :update, @material
  end

  def prevent_shared_caching
    response.headers["Cache-Control"] = "private, no-store"
  end
end
