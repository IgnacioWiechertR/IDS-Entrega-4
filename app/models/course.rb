class Course < ApplicationRecord
  acts_as_tenant :university
  belongs_to :faculty

  has_many :sections, dependent: :restrict_with_error
  has_many :course_coordinators, dependent: :restrict_with_error
  has_many :materials, dependent: :restrict_with_error
  has_many :announcements, dependent: :restrict_with_error

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :university_id }
  validate :faculty_in_same_university

  private

  # Inside the active university (A3) a faculty of another university is not visible, so an id without a
  # visible faculty also counts as a mismatch.
  def faculty_in_same_university
    same_university = faculty ? faculty.university_id == university_id : faculty_id.nil?
    errors.add(:faculty, :must_match_university) unless same_university
  end
end
