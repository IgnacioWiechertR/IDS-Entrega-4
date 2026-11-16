class AttendanceRecord < ApplicationRecord
  include InheritsUniversity

  enum :status, { presente: "presente", ausente: "ausente" }, validate: true

  belongs_to :attendance_session
  belongs_to :student, class_name: "User"
  # B7: who changed the mark after it was saved; nil while the mark is the one first recorded.
  belongs_to :corrected_by, class_name: "User", optional: true

  inherits_university_from :attendance_session
  accounts_in_university :corrected_by

  validates :student_id, uniqueness: { scope: :attendance_session_id }

  def corrected?
    corrected_by_id.present?
  end

  # Saves the mark. Changing a mark that was already saved is a correction (B7) and keeps its author.
  def mark!(status, by:)
    self.status = status
    assign_attributes(corrected_by: by, corrected_at: Time.current) if persisted? && status_changed?
    save!
  end
end
