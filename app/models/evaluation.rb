class Evaluation < ApplicationRecord
  include InheritsUniversity

  belongs_to :section
  has_many :grades, dependent: :destroy

  inherits_university_from :section

  validates :name, presence: true
  validates :weight, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validate :section_total_within_100

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
