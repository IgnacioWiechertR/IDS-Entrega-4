class Enrollment < ApplicationRecord
  include InheritsUniversity

  belongs_to :section
  belongs_to :student, class_name: "User"

  inherits_university_from :section
end
