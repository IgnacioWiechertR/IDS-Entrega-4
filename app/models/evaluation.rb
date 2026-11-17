class Evaluation < ApplicationRecord
  include InheritsUniversity

  belongs_to :section
  has_many :grades, dependent: :destroy

  inherits_university_from :section

  # C14 (DEC-18): a 4.0 needs half of the maximum score. The same scale for every evaluation.
  PASSING_RATIO = BigDecimal("0.5")

  validates :name, :due_on, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :max_points, numericality: { greater_than: 0 }, allow_nil: true
  validate :section_total_within_100

  # "Control 1 (ICC1001 · Sección 1)", for notifications.
  def title_with_section
    "#{name} (#{section.course.code} · Sección #{section.number})"
  end

  # C14: points needed for a 4.0, or nil without a maximum score.
  def passing_points
    max_points && max_points * PASSING_RATIO
  end

  # C14: the grade (1.0–7.0, one decimal, half up) for a score on this evaluation, or nil without a maximum score.
  # Below the passing points the scale goes from 1.0 to 4.0, and from there up to 7.0 at the maximum.
  def score_for(points)
    return unless max_points

    points = BigDecimal(points.to_s)
    grade = if points < passing_points
      1 + 3 * points / passing_points
    else
      4 + 3 * (points - passing_points) / (max_points - passing_points)
    end
    grade.round(1, BigDecimal::ROUND_HALF_UP)
  end

  private

  # The weights of all the evaluations of a section add up to 100 % at most.
  def section_total_within_100
    return unless section && weight

    others = section.evaluations.where.not(id: id).sum(:weight)
    return if others + weight <= 100

    available = ActiveSupport::NumberHelper.number_to_rounded(100 - others, precision: 2, strip_insignificant_zeros: true)
    errors.add(:weight, :exceeds_section_total, available: available)
  end
end
