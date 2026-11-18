# C8: the profesor who rejected the grades of an evaluation edits the comment of that rejection.
# A rejection (C6) copies the same comment and reviewer into every grade it rejected, so "the comment" is the one
# shared by the evaluation's grades that are still `rechazada`, with the same reviewer and the same text. Grades
# already corrected (back to `pendiente`, C7) or published keep the old text as history and are not touched.
class RejectionCommentUpdateService
  Result = Struct.new(:count, :error, keyword_init: true) do
    def success? = error.nil?
  end

  def initialize(grade:, comment:)
    @grade = grade
    @comment = comment.to_s.strip
  end

  def call
    return Result.new(count: 0, error: :comment_required) if @comment.blank?

    count = self.class.rejection_of(@grade).update_all(rejection_comment: @comment, updated_at: Time.current)
    Result.new(count: count, error: nil)
  end

  # The still rejected grades of the same rejection as `grade`.
  def self.rejection_of(grade)
    grade.evaluation.grades.rechazada.where(reviewed_by_id: grade.reviewed_by_id, rejection_comment: grade.rejection_comment)
  end
end
