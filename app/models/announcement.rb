class Announcement < ApplicationRecord
  belongs_to :course
  belongs_to :section, optional: true
  belongs_to :author, class_name: "User"

  validates :subject, :body, presence: true
  validate :section_belongs_to_course
  validate :author_belongs_to_university

  private

  def section_belongs_to_course
    return unless section && course

    errors.add(:section, "debe pertenecer a la asignatura") unless section.course_id == course.id
  end

  def author_belongs_to_university
    return unless author && course

    errors.add(:author, "debe pertenecer a la universidad") unless author.university_id == course.university_id
  end
end
