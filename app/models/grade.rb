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
  validate :points_within_max_points
  validates :rejection_comment, presence: true, if: :rechazada?
  validates :student_id, uniqueness: { scope: :evaluation_id }

  # C4: only preliminary grades can be deleted; an official one is never changed from the application.
  before_destroy :keep_published_grade

  private

  # C14: with a maximum score on the evaluation, the score cannot exceed it (so the converted grade stays ≤ 7.0).
  def points_within_max_points
    max = evaluation&.max_points
    return unless max && points && points > max

    errors.add(:points, :above_max_points, max: ActiveSupport::NumberHelper.number_to_rounded(max, precision: 2, strip_insignificant_zeros: true))
  end

  def keep_published_grade
    return unless publicada?

    errors.add(:base, :published_grade_cannot_be_deleted)
    throw :abort
  end
end
