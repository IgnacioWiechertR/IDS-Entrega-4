module ProfessorAssignment
  extend ActiveSupport::Concern

  included do
    validates :section_id,
      uniqueness: {
        conditions: -> { where(role: "profesor") },
        message: "ya tiene un profesor asignado"
      }, if: :professor_assignment?

    validate :valid_professor_assignment, if: :professor_assignment?
  end

  private

  def professor_assignment?
    role == "profesor"
  end

  def valid_professor_assignment
    return unless section && user && assigned_by

    errors.add(:user, "debe tener el rol de profesor") unless user.profesor?
    unless user.university_id == section.university_id
      errors.add(:user, "debe pertenecer a la universidad de la sección")
    end

    unless assigned_by.administrativo? && assigned_by.university_id == section.university_id
      errors.add(:assigned_by, "debe ser un administrativo de la universidad de la sección")
    end

    unless section.course&.university_id == section.university_id &&
        section.term&.university_id == section.university_id
      errors.add(:section, "debe tener una asignatura y un período de su misma universidad")
    end
  end
end
