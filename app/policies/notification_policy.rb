class NotificationPolicy
  include CanCan::Ability

  def initialize(user)
    # C12: every account with a university has an inbox; the director has none and receives no notifications.
    # The controller reads them from current_user, so there is no `can :read, Notification` (the old scaffold
    # listed Notification.all).
    can :read, :notifications if user.university_id.present?
  end
end
