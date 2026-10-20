class Enrollment < ApplicationRecord
  include InheritsUniversity
  include OneRolePerCourse

  belongs_to :section
  belongs_to :student, class_name: "User"

  inherits_university_from :section
  accounts_in_university :student
  one_role_per_course :student, if: :active?

  validates :student_id, uniqueness: { scope: :section_id }
  validate :student_account

  private

  def student_account
    errors.add(:student, :must_be_student) if student && !student.student_account?
  end
end
