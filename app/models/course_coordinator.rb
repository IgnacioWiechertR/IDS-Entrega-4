class CourseCoordinator < ApplicationRecord
  include InheritsUniversity

  belongs_to :course
  belongs_to :term
  belongs_to :user
  belongs_to :assigned_by, class_name: "User"

  inherits_university_from :course
  accounts_in_university :user

  # Inherited from T7 and backed by a database index. A15's cardinality is still pending confirmation.
  validates :course_id, uniqueness: { scope: :term_id }
  validate :profesor_account
  validate :term_in_same_university
  validate :assigned_by_authorized

  private

  # Trello A15: the coordinator is a profesor of the same university.
  def profesor_account
    errors.add(:user, :must_be_profesor) if user && !user.profesor?
  end

  def term_in_same_university
    errors.add(:term, :must_match_university) if term && term.university_id != university_id
  end

  def assigned_by_authorized
    return unless assigned_by
    return if assigned_by.director?

    unless assigned_by.administrativo? && assigned_by.university_id == university_id
      errors.add(:assigned_by, :must_be_authorized_assigner)
    end
  end
end
