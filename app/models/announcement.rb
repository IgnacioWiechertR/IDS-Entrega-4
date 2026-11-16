class Announcement < ApplicationRecord
  include InheritsUniversity

  belongs_to :course
  belongs_to :section, optional: true
  belongs_to :author, class_name: "User"

  # B11: the announcement belongs to the university of its course, and so does its author.
  inherits_university_from :course
  accounts_in_university :author

  validates :subject, :body, presence: true
  validate :section_belongs_to_course

  private

  def section_belongs_to_course
    return unless section && course

    errors.add(:section, :must_match_course) unless section.course_id == course.id
  end
end
