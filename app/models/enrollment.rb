class Enrollment < ApplicationRecord
  belongs_to :section
  belongs_to :student, class_name: "User"
end
