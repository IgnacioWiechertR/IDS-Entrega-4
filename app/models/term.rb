class Term < ApplicationRecord
  acts_as_tenant :university
  # A term with sections or coordinators is part of the academic history: it is not deleted with them.
  has_many :sections, dependent: :restrict_with_error
  has_many :course_coordinators, dependent: :restrict_with_error

  validates :name, :starts_on, :ends_on, presence: true
  validates :name, uniqueness: { scope: :university_id, case_sensitive: false }
  validates :current, uniqueness: { scope: :university_id, message: :only_one_current }, if: :current?
  validate :ends_after_start

  # The current term of the active university, or nil.
  def self.current_term = find_by(current: true)

  # "Cursos anteriores": a term that started before the current one. Without a current term nothing is past.
  def past?(current_term)
    current_term.present? && starts_on < current_term.starts_on
  end

  # Saves the term and, when it is marked as current, unmarks the previous current term of its university in the
  # same transaction, so there is always at most one. Returns false (and changes nothing) when it is invalid.
  def save_marking_current
    saved = false
    transaction do
      Term.where(university_id: university_id, current: true).where.not(id: id).update_all(current: false) if current?
      saved = save
      raise ActiveRecord::Rollback unless saved
    end
    saved
  end

  private

  def ends_after_start
    errors.add(:ends_on, :before_start) if starts_on && ends_on && ends_on < starts_on
  end
end
