class Announcement < ApplicationRecord
  belongs_to :course
  belongs_to :section, optional: true
  belongs_to :author, class_name: "User"
end
