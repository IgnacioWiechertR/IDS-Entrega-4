class EnrollmentsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :section, through: :course

  load_and_authorize_resource :enrollment, through: :section, except: [ :create ]

  def index
    @enrollments = @section.enrollments.includes(:student)
    @available_students = @section.student_accounts_without_role_in_course
  end

  def create
    authorize! :create, Enrollment.new(section: @section)

    student_ids = Array(params[:student_ids]).flatten.reject(&:blank?)

    if student_ids.empty?
      redirect_to course_section_enrollments_path(@course, @section), alert: "Debes seleccionar al menos un alumno para inscribir."
      return
    end

    rejected = enroll_all(student_ids)

    if rejected.any?
      reasons = rejected.map { |enrollment| "#{enrollment.student&.name}: #{enrollment.errors.map(&:message).to_sentence}" }
      redirect_to course_section_enrollments_path(@course, @section), alert: "No se inscribió a nadie. #{reasons.join(' · ')}"
    else
      redirect_to course_section_enrollments_path(@course, @section), notice: "Alumnos inscritos correctamente."
    end
  end

  def destroy
    @enrollment.destroy
    redirect_to course_section_enrollments_path(@course, @section), notice: "El alumno ha sido removido de la sección.", status: :see_other
  end

  private

  # All or nothing: if one student cannot be enrolled (for example, they already have a role in another
  # section of the course), nobody is, and the rejected enrollments are returned with their errors.
  def enroll_all(student_ids)
    rejected = []

    Enrollment.transaction do
      student_ids.each do |student_id|
        enrollment = @section.enrollments.find_or_initialize_by(student_id: student_id)
        enrollment.active = true
        rejected << enrollment unless enrollment.save
      end
      raise ActiveRecord::Rollback if rejected.any?
    end

    rejected
  end
end
