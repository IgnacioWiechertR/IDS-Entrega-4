class Material < ApplicationRecord
  MAX_FILE_SIZE = 50_000_000

  belongs_to :course
  belongs_to :uploaded_by, class_name: "User", optional: true, inverse_of: :uploaded_materials
  has_one_attached :file, service: ->(material) { MaterialStorageService.for(material.course) }

  attr_readonly :course_id, :uploaded_by_id

  validates :title, presence: true
  validate :valid_upload_author, on: :create
  validate :file_meets_upload_rules, if: -> { new_record? || attachment_changes.key?("file") }

  private

  def valid_upload_author
    return unless uploaded_by

    unless uploaded_by.profesor? && uploaded_by.university_id == course&.university_id
      errors.add(:uploaded_by, "debe ser un profesor de la universidad del curso")
    end
  end

  def file_meets_upload_rules
    if !file.attached?
      errors.add(:file, :blank)
    elsif file.blob.byte_size.zero?
      errors.add(:file, :empty)
    elsif file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, :too_large, max: 50)
    elsif !MaterialFileFormat.allowed?(file.filename.to_s, io: uploaded_file_io)
      errors.add(:file, :unsupported_format)
    end
  end

  def uploaded_file_io
    attachable = attachment_changes["file"]&.attachable
    case attachable
    when Hash then attachable[:io]
    when ActionDispatch::Http::UploadedFile then attachable.tempfile
    else attachable
    end
  end
end
