# C6: "Rechazar notas" sends the pending grades of an evaluation back to the ayudante with a mandatory comment.
# Like the approval, it only acts on `pendiente` grades.
class GradeRejectionService
  Result = Struct.new(:count, :assistant_ids, :error, keyword_init: true) do
    def success? = error.nil?
  end

  def initialize(evaluation:, reviewer:, comment:)
    @evaluation = evaluation
    @reviewer = reviewer
    @comment = comment.to_s.strip
  end

  def call
    return Result.new(count: 0, assistant_ids: [], error: :comment_required) if @comment.blank?

    Grade.transaction do
      grades = @evaluation.grades.pendiente.lock.pluck(:id, :entered_by_id)

      if grades.empty?
        Result.new(count: 0, assistant_ids: [], error: :none_pending)
      else
        Grade.where(id: grades.map(&:first))
          .update_all(status: "rechazada", rejection_comment: @comment, reviewed_by_id: @reviewer.id, updated_at: Time.current)
        Result.new(count: grades.size, assistant_ids: grades.map(&:second).uniq, error: nil)
      end
    end
  end
end
