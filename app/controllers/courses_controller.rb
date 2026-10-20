class CoursesController < ApplicationController
  load_and_authorize_resource

  def index
    @courses = @courses.includes(:faculty).order(:code)
    @coordinators = current_user.administrativo? ? current_coordinators_for(@courses) : {}
  end

  # GET /courses/1
  def show
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
    term = Term.find_by(current: true)
    return {} unless term

    CourseCoordinator.includes(:user).where(term: term, course_id: courses.map(&:id)).index_by(&:course_id)
  end
end
