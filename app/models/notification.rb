class Notification < ApplicationRecord
  include InheritsUniversity

  belongs_to :recipient, class_name: "User"

  # The director has no university, so it cannot receive notifications (none are sent to it in E5).
  inherits_university_from :recipient
end
