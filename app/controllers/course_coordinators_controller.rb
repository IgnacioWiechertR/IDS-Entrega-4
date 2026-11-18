class CourseCoordinatorsController < ApplicationController
  before_action :authorize_assignment

  def index
    @assignment = CourseCoordinator.new
    load_assignment_options
  end

  def create
    attributes = params.expect(course_coordinator: [ :course_id, :term_id, :user_id ])
    course = available_courses.find(attributes[:course_id])
    @term = available_terms.find(attributes[:term_id])
    professor = available_professors.find(attributes[:user_id])
    @assignment = CourseCoordinator.new(
      course: course, term: @term, user: professor,
      university: current_university, assigned_by: current_user
    )
    authorize! :create, @assignment

    if @assignment.save
      redirect_to course_coordinators_path(term_id: @term.id),
        notice: "Coordinador asignado correctamente.", status: :see_other
    else
      load_assignment_options
      render :index, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to course_coordinators_path(term_id: @term.id),
      alert: "La asignatura ya tiene un coordinador en este período. Actualiza la página para verlo.",
      status: :see_other
  end

  private

  def authorize_assignment
    authorize! action_name.to_sym, CourseCoordinator
  end

  def available_courses
    Course.joins(:faculty).where(university_id: current_university.id,
      faculties: { university_id: current_university.id })
  end

  def available_terms
    Term.where(university_id: current_university.id)
  end

  def available_professors
    User.profesor.where(university_id: current_university.id)
  end

  def load_assignment_options
    @terms = available_terms.order(current: :desc, starts_on: :desc, id: :desc)
    @term ||= if params[:term_id].present?
      @terms.find(params[:term_id])
    else
      @terms.find_by(current: true) || @terms.first
    end
    @courses = available_courses.order(:code, :id)
    @professors = available_professors.order(:first_name, :last_name, :id)
    @coordinators = CourseCoordinator.where(university_id: current_university.id,
      term: @term, course_id: @courses.select(:id)).includes(:user).group_by(&:course_id)
  end
end
