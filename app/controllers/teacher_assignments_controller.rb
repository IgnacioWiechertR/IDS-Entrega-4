class TeacherAssignmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_teacher_assignment

  def index
    @assignment = SectionStaff.new
    load_assignment_options
  end

  def create
    attributes = params.expect(teacher_assignment: [ :section_id, :user_id ])
    section = assignable_sections.find(attributes[:section_id])
    authorize! :assign_professor, section
    professor = available_professors.find(attributes[:user_id])

    @assignment = SectionStaff.new(
      section: section, user: professor, role: "profesor", assigned_by: current_user
    )

    if @assignment.save
      redirect_to teacher_assignments_path, notice: "Profesor asignado correctamente.", status: :see_other
    else
      load_assignment_options
      render :index, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to teacher_assignments_path,
      alert: "La sección ya tiene un profesor asignado. Actualiza la página para verlo.",
      status: :see_other
  end

  private

  def authorize_teacher_assignment
    authorize! :assign_professor, Section
  end

  def assignable_sections
    Section.joins(:course, :term).where(
      university_id: current_user.university_id,
      courses: { university_id: current_user.university_id },
      terms: { university_id: current_user.university_id }
    )
  end

  def available_professors
    User.profesor.where(university_id: current_user.university_id)
  end

  def load_assignment_options
    @sections = assignable_sections.includes(:course, :term, section_staffs: :user)
      .order(:course_id, :number, :id)
    @professors = available_professors.order(:first_name, :last_name, :id)
  end
end
