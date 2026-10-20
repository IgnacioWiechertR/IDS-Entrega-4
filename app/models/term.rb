class Term < ApplicationRecord
  belongs_to :university
  has_many :sections, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy

  validates :name, :starts_on, :ends_on, presence: true
  validates :current, uniqueness: { scope: :university_id, message: :only_one_current }, if: :current?
  validate :ends_after_start

  private

  def ends_after_start
    errors.add(:ends_on, :before_start) if starts_on && ends_on && ends_on < starts_on
  end
end
