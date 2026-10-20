class Grade < ApplicationRecord
  include InheritsUniversity

  # pendiente and rechazada are preliminary; publicada is official and visible to the student.
  # The transitions belong to the grade cards (C1, C5, C6).
  enum :status, { pendiente: "pendiente", rechazada: "rechazada", publicada: "publicada" },
       default: :pendiente, validate: true

  belongs_to :evaluation
  belongs_to :student, class_name: "User"
  belongs_to :entered_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  inherits_university_from :evaluation
  accounts_in_university :student

  scope :preliminares, -> { where(status: %w[pendiente rechazada]) }
  scope :publicadas, -> { publicada }

  validates :score, presence: true, numericality: { greater_than_or_equal_to: 1.0, less_than_or_equal_to: 7.0 }
  validates :points, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :rejection_comment, presence: true, if: :rechazada?
  validates :student_id, uniqueness: { scope: :evaluation_id }
end
