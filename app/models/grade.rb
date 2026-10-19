class Grade < ApplicationRecord
  belongs_to :evaluation
  belongs_to :student, class_name: "User"
  belongs_to :entered_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true
end
