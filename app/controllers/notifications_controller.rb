# C12: the inbox. Each user sees only their own notifications, newest first; opening it marks them as read.
class NotificationsController < ApplicationController
  before_action -> { response.headers["Cache-Control"] = "private, no-store" }

  def index
    authorize! :read, :notifications

    @notifications = visible_notifications.includes(:announcement).order(created_at: :desc, id: :desc).limit(50).to_a
    visible_notifications.unread.update_all(read_at: Time.current)
  end
end
