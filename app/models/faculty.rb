class Faculty < ApplicationRecord
  belongs_to :university
  has_many :courses, dependent: :destroy
end
