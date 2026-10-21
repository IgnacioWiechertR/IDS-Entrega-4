class AttendanceSession < ApplicationRecord
  include InheritsUniversity

  belongs_to :section
  belongs_to :recorded_by, class_name: "User"
  has_many :attendance_records, dependent: :destroy

  inherits_university_from :section

  validates :held_on, presence: true, uniqueness: { scope: :section_id }
  validate :held_on_not_in_the_future

  private

  # Classes are face to face (B6): attendance is taken on the day of the class or later, never ahead.
  def held_on_not_in_the_future
    errors.add(:held_on, :in_the_future) if held_on&.future?
  end
end
