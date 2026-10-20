class SectionStaff < ApplicationRecord
  include InheritsUniversity
  include OneRolePerCourse

  ROLES = %w[profesor ayudante].freeze
  include ProfessorAssignment

  belongs_to :section
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"

  inherits_university_from :section
  accounts_in_university :user
  one_role_per_course :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :section_id }
  validate :account_fits_role

  private

  # The profesor of a section is a profesor account; an ayudante is a student account (Trello A23).
  def account_fits_role
    return unless user

    if role == "profesor" && !user.profesor?
      errors.add(:user, :must_be_profesor)
    elsif role == "ayudante" && !user.student_account?
      errors.add(:user, :must_be_student)
    end
  end
end
