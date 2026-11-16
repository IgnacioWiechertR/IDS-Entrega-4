class Material < ApplicationRecord
  belongs_to :course
  belongs_to :uploaded_by, class_name: "User", optional: true, inverse_of: :uploaded_materials
  # Active Storage purges the detached blob asynchronously after the destroy commits.
  has_one_attached :file

  attr_readonly :course_id, :uploaded_by_id
  validate :valid_upload_author, on: :create

  private

  def valid_upload_author
    return unless uploaded_by

    unless uploaded_by.profesor? && uploaded_by.university_id == course&.university_id
      errors.add(:uploaded_by, "debe ser un profesor de la universidad del curso")
    end
  end
end
