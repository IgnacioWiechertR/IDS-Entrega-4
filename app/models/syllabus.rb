# The syllabus of a course in one term. The platform only stores the file: creating or editing its content stays
# outside the app (Entrega 2, "Rigidez del Syllabus"). It lives in the same storage as the materials (Entrega 3).
class Syllabus < ApplicationRecord
  include InheritsUniversity

  MAX_FILE_SIZE = Material::MAX_FILE_SIZE

  belongs_to :course
  belongs_to :term
  belongs_to :uploaded_by, class_name: "User", optional: true, inverse_of: :uploaded_syllabi

  has_one_attached :file, service: ->(syllabus) { MaterialStorageService.for(syllabus.course) }

  inherits_university_from :course

  attr_readonly :course_id, :term_id

  validates :term_id, uniqueness: { scope: :course_id }
  validate :term_in_same_university
  validate :file_is_a_pdf, if: -> { new_record? || attachment_changes.key?("file") }
  validate :not_replaced_once_term_started, on: :update

  # Once its term began the syllabus stays as it was: it can be replaced only before the term starts. A course that
  # reached its term without one may still upload it once, so it is never left without a syllabus.
  def locked?
    persisted? && term.present? && term.started?
  end

  private

  def not_replaced_once_term_started
    errors.add(:file, :locked_during_term) if attachment_changes.key?("file") && locked?
  end

  def term_in_same_university
    errors.add(:term, :must_match_university) if term && term.university_id != university_id
  end

  # Only PDF: it is the format of the official syllabus and every browser opens it.
  def file_is_a_pdf
    if !file.attached?
      errors.add(:file, :blank)
    elsif file.blob.byte_size.zero?
      errors.add(:file, :empty)
    elsif file.blob.byte_size > MAX_FILE_SIZE
      errors.add(:file, :too_large, max: MAX_FILE_SIZE / 1_000_000)
    elsif File.extname(file.filename.to_s).downcase != ".pdf" ||
          !MaterialFileFormat.allowed?(file.filename.to_s, io: uploaded_file_io)
      errors.add(:file, :not_a_pdf)
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
