class University < ApplicationRecord
  enum :size, { grande: "grande", pequena: "pequena" }, validate: true

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  has_many :users, dependent: :destroy
  has_many :faculties, dependent: :destroy
  has_many :terms, dependent: :destroy
  has_many :courses, dependent: :destroy
  has_many :sections, dependent: :destroy
end
