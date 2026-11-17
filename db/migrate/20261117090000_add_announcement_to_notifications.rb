class AddAnnouncementToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_reference :notifications, :announcement, foreign_key: true, index: false
    add_index :notifications, [ :announcement_id, :recipient_id ], unique: true,
      name: "index_notifications_on_announcement_and_recipient"
  end
end
