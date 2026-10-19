class AttendanceSessionsController < ApplicationController
  load_and_authorize_resource
  before_action :set_attendance_session, only: %i[ show edit update destroy ]

  # GET /attendance_sessions
  def index
    @attendance_sessions = AttendanceSession.all
  end

  # GET /attendance_sessions/1
  def show
  end

  # GET /attendance_sessions/new
  def new
    @attendance_session = AttendanceSession.new
  end

  # GET /attendance_sessions/1/edit
  def edit
  end

  # POST /attendance_sessions
  def create
    @attendance_session = AttendanceSession.new(attendance_session_params)

    if @attendance_session.save
      redirect_to @attendance_session, notice: "Attendance session was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /attendance_sessions/1
  def update
    if @attendance_session.update(attendance_session_params)
      redirect_to @attendance_session, notice: "Attendance session was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /attendance_sessions/1
  def destroy
    @attendance_session.destroy!
    redirect_to attendance_sessions_path, notice: "Attendance session was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_attendance_session
      @attendance_session = AttendanceSession.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def attendance_session_params
      params.expect(attendance_session: [ :section_id, :held_on, :recorded_by_id ])
    end
end
