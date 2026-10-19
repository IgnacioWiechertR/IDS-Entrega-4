class AttendanceRecordsController < ApplicationController
  before_action :set_attendance_record, only: %i[ show edit update destroy ]

  # GET /attendance_records
  def index
    @attendance_records = AttendanceRecord.all
  end

  # GET /attendance_records/1
  def show
  end

  # GET /attendance_records/new
  def new
    @attendance_record = AttendanceRecord.new
  end

  # GET /attendance_records/1/edit
  def edit
  end

  # POST /attendance_records
  def create
    @attendance_record = AttendanceRecord.new(attendance_record_params)

    if @attendance_record.save
      redirect_to @attendance_record, notice: "Attendance record was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /attendance_records/1
  def update
    if @attendance_record.update(attendance_record_params)
      redirect_to @attendance_record, notice: "Attendance record was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /attendance_records/1
  def destroy
    @attendance_record.destroy!
    redirect_to attendance_records_path, notice: "Attendance record was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_attendance_record
      @attendance_record = AttendanceRecord.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def attendance_record_params
      params.expect(attendance_record: [ :attendance_session_id, :student_id, :status ])
    end
end
