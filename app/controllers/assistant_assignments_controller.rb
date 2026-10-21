# A23: the administrativo, or the profesor who coordinates the course, assigns ayudantes to a section.
class AssistantAssignmentsController < ApplicationController
  before_action :set_section

  def index
    @assistants = @section.section_staffs.where(role: "ayudante").includes(:user, :assigned_by).order(:created_at)
    @available_accounts = @section.student_accounts_without_role_in_course
  end

  def create
    user_ids = Array(params[:user_ids]).compact_blank

    if user_ids.empty?
      redirect_to course_section_assistant_assignments_path(@course, @section), alert: "Debes seleccionar al menos una cuenta."
      return
    end

    rejected = assign_all(user_ids)

    if rejected.any?
      reasons = rejected.map { |staff| "#{staff.user&.name}: #{staff.errors.map(&:message).to_sentence}" }
      redirect_to course_section_assistant_assignments_path(@course, @section), alert: "No se asignó a nadie. #{reasons.join(' · ')}"
    else
      redirect_to course_section_assistant_assignments_path(@course, @section), notice: "Ayudantes asignados correctamente."
    end
  end

  # Only ayudantes are removed here: the profesor of the section is managed by A22.
  def destroy
    staff = @section.section_staffs.where(role: "ayudante").find(params.expect(:id))
    authorize! :destroy, staff
    staff.destroy!

    redirect_to course_section_assistant_assignments_path(@course, @section),
                notice: "El ayudante fue quitado de la sección.", status: :see_other
  end

  private

  # The course and the section are scoped by the active university (A3), so one from the other university is a 404.
  def set_section
    @course = Course.find(params.expect(:course_id))
    @section = @course.sections.find(params.expect(:section_id))
    authorize! :create, SectionStaff.new(section: @section, role: "ayudante")
  end

  # All or nothing, like enrolling students (A24): if one account cannot be an ayudante here (another
  # university, or already a role in this course and term), nobody is assigned. Who assigned and when stay in
  # assigned_by and created_at.
  def assign_all(user_ids)
    rejected = []

    SectionStaff.transaction do
      user_ids.each do |user_id|
        staff = SectionStaff.new(section: @section, user_id: user_id, role: "ayudante", assigned_by: current_user)
        rejected << staff unless staff.save
      end
      raise ActiveRecord::Rollback if rejected.any?
    end

    rejected
  end
end
