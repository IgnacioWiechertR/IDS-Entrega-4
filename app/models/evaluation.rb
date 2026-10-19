class Evaluation < ApplicationRecord
  belongs_to :section
  has_many :grades, dependent: :destroy
end
