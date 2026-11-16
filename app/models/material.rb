class Material < ApplicationRecord
  belongs_to :course
  has_one_attached :file, service: ->(material) { MaterialStorageService.for(material.course) }

  validates :title, presence: true
  validate :file_is_present_and_not_empty, on: :create

  private

  def file_is_present_and_not_empty
    if !file.attached?
      errors.add(:file, :blank)
    elsif file.blob.byte_size.zero?
      errors.add(:file, :empty)
    end
  end
end
