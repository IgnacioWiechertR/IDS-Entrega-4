class SectionStaffsController < ApplicationController
  load_and_authorize_resource
  before_action :set_section_staff, only: %i[ show edit update destroy ]

  # GET /section_staffs
  def index
    @section_staffs = SectionStaff.all
  end

  # GET /section_staffs/1
  def show
  end

  # GET /section_staffs/new
  def new
    @section_staff = SectionStaff.new
  end

  # GET /section_staffs/1/edit
  def edit
  end

  # POST /section_staffs
  def create
    @section_staff = SectionStaff.new(section_staff_params)

    if @section_staff.save
      redirect_to @section_staff, notice: "Section staff was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /section_staffs/1
  def update
    if @section_staff.update(section_staff_params)
      redirect_to @section_staff, notice: "Section staff was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /section_staffs/1
  def destroy
    @section_staff.destroy!
    redirect_to section_staffs_path, notice: "Section staff was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_section_staff
      @section_staff = SectionStaff.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def section_staff_params
      params.expect(section_staff: [ :section_id, :user_id, :role, :assigned_by_id ])
    end
end
