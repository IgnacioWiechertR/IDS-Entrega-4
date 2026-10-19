class MaterialsController < ApplicationController
  load_and_authorize_resource
  before_action :set_material, only: %i[ show edit update destroy ]

  # GET /materials
  def index
    @materials = Material.all
  end

  # GET /materials/1
  def show
  end

  # GET /materials/new
  def new
    @material = Material.new
  end

  # GET /materials/1/edit
  def edit
  end

  # POST /materials
  def create
    @material = Material.new(material_params)

    if @material.save
      redirect_to @material, notice: "Material was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /materials/1
  def update
    if @material.update(material_params)
      redirect_to @material, notice: "Material was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /materials/1
  def destroy
    @material.destroy!
    redirect_to materials_path, notice: "Material was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_material
      @material = Material.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def material_params
      params.expect(material: [ :course_id, :title, :file ])
    end
end
