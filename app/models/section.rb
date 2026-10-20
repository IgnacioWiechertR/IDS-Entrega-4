class Section < ApplicationRecord
  belongs_to :university
  belongs_to :course
  belongs_to :term
  has_many :section_staffs, dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :evaluations, dependent: :destroy
  has_many :attendance_sessions, dependent: :destroy
  has_many :announcements, dependent: :destroy

  validates :number, numericality: { only_integer: true, greater_than: 0 }
  validates :number, uniqueness: { scope: %i[course_id term_id] }
  validate :course_and_term_in_same_university

  private

  def course_and_term_in_same_university
    errors.add(:course, :must_match_university) if course && course.university_id != university_id
    errors.add(:term, :must_match_university) if term && term.university_id != university_id
  end
end
