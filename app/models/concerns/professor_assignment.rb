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

    unless authorized_assigner?
      errors.add(:assigned_by, "debe ser un administrativo de la universidad o el coordinador de la asignatura")
    end

    unless section.course&.university_id == section.university_id &&
        section.term&.university_id == section.university_id
      errors.add(:section, "debe tener una asignatura y un período de su misma universidad")
    end
  end

  # Trello A22: the administrativo of the university, or the profesor who coordinates the course in the
  # section's term.
  def authorized_assigner?
    return false unless assigned_by.university_id == section.university_id

    assigned_by.administrativo? || (assigned_by.profesor? && section.coordinated_by?(assigned_by))
  end
end
