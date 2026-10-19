class Evaluation < ApplicationRecord
  include InheritsUniversity

  belongs_to :section
  has_many :grades, dependent: :destroy

  inherits_university_from :section
end
