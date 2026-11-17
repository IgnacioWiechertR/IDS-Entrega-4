class Notification < ApplicationRecord
  include InheritsUniversity

  belongs_to :recipient, class_name: "User"
  belongs_to :announcement, optional: true

  # The director has no university, so it cannot receive notifications (none are sent to it in E5).
  inherits_university_from :recipient

  scope :unread, -> { where(read_at: nil) }
  scope :visible_to, ->(user) {
    own = where(recipient: user)
    own.where(announcement_id: nil).or(own.where(announcement_id: Announcement.readable_by(user).select(:id)))
  }

  validates :kind, :message, presence: true
  validates :announcement, presence: true, if: -> { kind == "anuncio_nuevo" }
  validate :announcement_in_same_university

  private

  def announcement_in_same_university
    if announcement && announcement.university_id != university_id
      errors.add(:announcement, :must_match_university)
    end
  end
end
