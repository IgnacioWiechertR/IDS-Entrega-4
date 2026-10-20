class Term < ApplicationRecord
  acts_as_tenant :university
  has_many :sections, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy

  validates :name, :starts_on, :ends_on, presence: true
  validates :current, uniqueness: { scope: :university_id, message: :only_one_current }, if: :current?
  validate :ends_after_start

  # The current term of the active university, or nil.
  def self.current_term = find_by(current: true)

  # "Cursos anteriores": a term that started before the current one. Without a current term nothing is past.
  def past?(current_term)
    current_term.present? && starts_on < current_term.starts_on
  end

  private

  def ends_after_start
    errors.add(:ends_on, :before_start) if starts_on && ends_on && ends_on < starts_on
  end
end
