class MaterialsController < ApplicationController
  before_action :set_upload_course, only: %i[ new create ]

  # The old global scaffold stays closed until B2 defines how materials are listed.
  def index
    authorize! :index, Material
  end

  def new
  end

  def create
    attributes = params.expect(material: [ :title, :file ])
    @material.title = attributes[:title]
    # B3: the author is the signed-in user, never a parameter.
    @material.uploaded_by = current_user
    upload = attributes[:file]

    # B1 accepts a fresh multipart upload, never an existing blob's signed ID.
    if upload.is_a?(ActionDispatch::Http::UploadedFile)
      @material.file = upload
      if @material.save
        redirect_to new_course_material_path(@course),
          notice: "Material subido correctamente.", status: :see_other
        return
      end
    else
      @material.valid?
      @material.errors.add(:file, "debe seleccionarse desde tu equipo") if upload.present?
    end

    render :new, status: :unprocessable_content
  rescue MaterialStorageService::UniversityNotConfigured
    @material.errors.add(:file, "no se pudo guardar porque el almacenamiento de esta universidad no está configurado")
    render :new, status: :unprocessable_content
  end

  private

  def set_upload_course
    @course = Course.find(params.expect(:course_id))
    @material = @course.materials.new
    authorize! :create, @material
  end
end
