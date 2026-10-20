# Attendance of a section (B6, B8–B10). The profesor of the section takes it and sees the whole table;
# each student sees only their own marks. A section of another university responds 404 (A3).
class AttendanceController < ApplicationController
  before_action :set_section, except: :index

  # The sections the user teaches and, for a student account, their % in each one (B8).
  def index
    authorize! :index, :attendance
    @taught_sections = sections_for(:take_attendance)
    @enrolled_sections = sections_for(:read_own_attendance)
  end

  def show
    @calculator = AttendanceCalculatorService.new(@section)

    if can?(:read_attendance_sheet, @section)
      authorize! :read_attendance_sheet, @section
      render :section
    else
      authorize! :read_own_attendance, @section
      render :student
    end
  end

  # B6: the list of the section for one date, today by default. A date already taken shows its marks.
  def edit
    authorize! :take_attendance, @section
    @held_on = requested_date
    load_list
  end

  def update
    authorize! :take_attendance, @section
    attributes = params.expect(attendance: [ :held_on, statuses: {} ])

    if @section.active_students.none?
      redirect_to section_attendance_path(@section), alert: "Sección sin matrículas activas.", status: :see_other
      return
    end

    recorder = AttendanceRecorderService.new(section: @section, held_on: attributes[:held_on], recorded_by: current_user)
    if recorder.call(attributes[:statuses] || {})
      redirect_to section_attendance_path(@section), notice: "Asistencia del #{l(recorder.session.held_on)} guardada.",
        status: :see_other
    else
      @held_on = recorder.session.held_on || Date.current
      @errors = recorder.session.errors
      load_list
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_section
    @section = Section.find(params.expect(:section_id))
  end

  def sections_for(action)
    Section.accessible_by(current_ability, action).includes(:course, :term)
      .sort_by { |section| [ -section.term.starts_on.jd, section.course.code, section.number ] }
  end

  def requested_date
    params[:date].present? ? Date.iso8601(params[:date]) : Date.current
  rescue Date::Error
    Date.current
  end

  def load_list
    @calculator = AttendanceCalculatorService.new(@section)
    @session = @section.attendance_sessions.find_by(held_on: @held_on)
  end
end
