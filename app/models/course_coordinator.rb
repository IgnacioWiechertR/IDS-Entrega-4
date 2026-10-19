class CourseCoordinator < ApplicationRecord
  include InheritsUniversity

  belongs_to :course
  belongs_to :term
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"

  inherits_university_from :course
  accounts_in_university :user

  validates :course_id, uniqueness: { scope: :term_id }
  validate :profesor_account
  validate :term_in_same_university

  private

  # Trello A15: the coordinator is a profesor of the same university.
  def profesor_account
    errors.add(:user, :must_be_profesor) if user && !user.profesor?
  end

  def term_in_same_university
    errors.add(:term, :must_match_university) if term && term.university_id != university_id
  end
end
