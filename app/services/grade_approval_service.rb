# C5: "Aceptar notas" makes the pending grades of an evaluation official (publicada) in a single operation.
# Only `pendiente` grades are approved: `rechazada` ones wait for the ayudante to correct them (C7) and
# `publicada` ones are never touched. If any score is outside 1.0–7.0, nothing is published.
class GradeApprovalService
  Result = Struct.new(:count, :student_ids, :error, keyword_init: true) do
    def success? = error.nil?
  end

  def initialize(evaluation:, reviewer:)
    @evaluation = evaluation
    @reviewer = reviewer
  end

  def call
    Grade.transaction do
      grades = @evaluation.grades.pendiente.lock.pluck(:id, :student_id, :score)

      if grades.empty?
        Result.new(count: 0, student_ids: [], error: :none_pending)
      elsif grades.any? { |_id, _student_id, score| score.nil? || score < 1 || score > 7 }
        Result.new(count: 0, student_ids: [], error: :out_of_range)
      else
        # One UPDATE for the whole evaluation: 100 grades are published well under 3 seconds.
        Grade.where(id: grades.map(&:first)).update_all(status: "publicada", reviewed_by_id: @reviewer.id, updated_at: Time.current)
        Result.new(count: grades.size, student_ids: grades.map(&:second), error: nil)
      end
    end
  end
end
