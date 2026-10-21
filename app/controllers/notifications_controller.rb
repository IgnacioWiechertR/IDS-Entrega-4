# C12: the inbox. Each user sees only their own notifications, newest first; opening it marks them as read.
class NotificationsController < ApplicationController
  def index
    authorize! :read, :notifications

    @notifications = current_user.notifications.order(created_at: :desc, id: :desc).limit(50).to_a
    current_user.notifications.unread.update_all(read_at: Time.current)
  end
end
