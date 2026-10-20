class EnrollmentsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :section, through: :course

  load_and_authorize_resource :enrollment, through: :section, except: [ :create ]

  def index
    @enrollments = @section.enrollments.includes(:student)

    @available_students = User.where(role: "alumno", university_id: @section.university_id)
                              .where.not(id: @enrollments.select(:student_id))
                              .order(:last_name, :first_name)
  end

  def create
    authorize! :create, Enrollment.new(section: @section)

    student_ids = Array(params[:student_ids]).flatten.reject(&:blank?)

    if student_ids.empty?
      redirect_to course_section_enrollments_path(@course, @section), alert: "Debes seleccionar al menos un alumno para inscribir."
      return
    end

    student_ids.each do |student_id|
      @section.enrollments.find_or_create_by!(student_id: student_id) do |enrollment|
        enrollment.active = true
      end
    end

    redirect_to course_section_enrollments_path(@course, @section), notice: "Alumnos inscritos correctamente."
  end

  def destroy
    @enrollment.destroy
    redirect_to course_section_enrollments_path(@course, @section), notice: "El alumno ha sido removido de la sección.", status: :see_other
  end
end
