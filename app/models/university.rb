class University < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :faculties, dependent: :destroy
  has_many :terms, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :sections, dependent: :destroy
end
