class CoursesController < ApplicationController
  load_and_authorize_resource

  # One card in "Mis cursos": a course in one term, through the user's section or coordination.
  CourseEntry = Struct.new(:course, :term, :role, :path, keyword_init: true)

  # GET /courses: the catalog of the university for the administrativo and the director (A12), "Mis cursos" for
  # everyone else. Both have the tabs "Cursos" and "Cursos anteriores" (?tab=anteriores).
  def index
    @tab = params[:tab] == "anteriores" ? :past : :current
    @current_term = Term.current_term

    if catalog_view?
      courses = @courses.includes(:faculty, sections: :term).order(:code).to_a
      @past, @present = courses.partition { |course| past_course?(course) }
      @coordinators = current_coordinators_for(courses)
    else
      @past, @present = my_course_entries.partition { |entry| entry.term.past?(@current_term) }
      @present.sort_by! { |entry| [ entry.course.code, -entry.term.starts_on.jd ] }
      @past.sort_by! { |entry| [ -entry.term.starts_on.jd, entry.course.code ] }
    end
  end

  # GET /courses/1: the overview of the course in one term (?term_id=, by default the current one) for the
  # administrativo, the director and the coordinators of the course. Profesores, ayudantes and students go
  # straight to their own section.
  def show
    if (section = own_section)
      redirect_to course_section_path(@course, section)
      return
    end

    @terms = Term.where(id: @course.sections.select(:term_id)).order(starts_on: :desc).to_a
    @term = @terms.find { |term| term.id.to_s == params[:term_id].to_s } || @terms.find(&:current) || @terms.first
    @sections = @term ? @course.sections.where(term: @term).includes(section_staffs: :user).order(:number).to_a : []
    @stats = @sections.to_h { |section| [ section.id, SectionStatsService.new(section) ] }
    @coordinator = @term && CourseCoordinator.includes(:user).find_by(course: @course, term: @term)&.user
  end

  # GET /courses/new
  def new
  end

  # GET /courses/1/edit
  def edit
  end

  # POST /courses (A11)
  def create
    if @course.save
      redirect_to @course, notice: "El curso fue creado."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /courses/1 (A13)
  def update
    if @course.update(course_params)
      redirect_to @course, notice: "El curso fue actualizado.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /courses/1 (A14)
  def destroy
    if @course.destroy
      redirect_to courses_path, notice: "El curso fue eliminado.", status: :see_other
    else
      redirect_to @course, status: :see_other,
        alert: "No se puede eliminar el curso #{@course.errors.full_messages.to_sentence}. " \
               "Para mantener la trazabilidad, solo se eliminan cursos sin secciones, coordinadores, materiales ni avisos."
    end
  end

  private

  # The university comes from the active tenant, never from the form.
  def course_params
    params.expect(course: [ :faculty_id, :code, :name ])
  end

  # Coordinator of each course in the current term, indexed by course_id. Without a current term, none.
  def current_coordinators_for(courses)
    return {} unless @current_term

    CourseCoordinator.includes(:user).where(term: @current_term, course_id: courses.map(&:id)).index_by(&:course_id)
  end

  # "Cursos anteriores" of the catalog: courses whose sections all belong to terms before the current one. A course
  # without sections (just created) or without a current term stays in "Cursos".
  def past_course?(course)
    course.sections.any? && course.sections.all? { |section| section.term.past?(@current_term) }
  end

  # The user's courses, one per course and term. A coordinator goes to the course overview; a profesor, ayudante or
  # student to their section (there is one per course and term, T7).
  def my_course_entries
    entries = {}

    current_user.course_coordinators.includes(:course, :term).each do |coordinator|
      next unless coordinator.course

      entries[[ coordinator.course_id, coordinator.term_id ]] = CourseEntry.new(
        course: coordinator.course, term: coordinator.term, role: "Coordinador",
        path: course_path(coordinator.course, term_id: coordinator.term_id)
      )
    end
    current_user.section_staffs.includes(section: %i[course term]).each do |staff|
      add_section_entry(entries, staff.section, staff.role.capitalize)
    end
    current_user.enrollments.where(active: true).includes(section: %i[course term]).each do |enrollment|
      add_section_entry(entries, enrollment.section, "Alumno")
    end

    entries.values
  end

  def add_section_entry(entries, section, role)
    return unless section&.course

    entries[[ section.course_id, section.term_id ]] ||= CourseEntry.new(
      course: section.course, term: section.term, role: role, path: course_section_path(section.course, section)
    )
  end

  # The section a profesor, ayudante or student is sent to from the course: the one of the current term, or else the
  # most recent. nil for the administrativo, the director and the coordinators, who see the course overview.
  def own_section
    return if catalog_view? || @course.course_coordinators.exists?(user: current_user)

    ids = current_user.section_staffs.pluck(:section_id) + current_user.enrollments.where(active: true).pluck(:section_id)
    @course.sections.joins(:term).where(id: ids).order("terms.current DESC", "terms.starts_on DESC").first
  end
end
