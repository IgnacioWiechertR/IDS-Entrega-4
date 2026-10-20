class Course < ApplicationRecord
  acts_as_tenant :university
  belongs_to :faculty
  has_many :sections, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy
  has_many :materials, dependent: :destroy
  has_many :announcements, dependent: :destroy

  validates :code, :name, presence: true
  validates :code, uniqueness: { scope: :university_id }
  validate :faculty_in_same_university

  private

  def faculty_in_same_university
    errors.add(:faculty, :must_match_university) if faculty && faculty.university_id != university_id
  end
end
