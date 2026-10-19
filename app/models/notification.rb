class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
end
