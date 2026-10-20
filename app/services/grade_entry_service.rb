# C1: the ayudante enters the preliminary grades of an evaluation, all in one submission.
# C7: a grade the profesor rejected is corrected in the same submission and goes back to `pendiente` (its
# rejection comment is kept as history). Pending and published grades are not touched here (editing them is C3).
# entries: { student_id => { score:, feedback:, points: } }. Rows without a score and students that are not
# actively enrolled in the section are skipped.
# All or nothing: if one grade is invalid, none is saved and the errors come back by student_id.
class GradeEntryService
  Result = Struct.new(:saved_count, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def initialize(evaluation:, author:, entries:)
    @evaluation = evaluation
    @author = author
    @entries = entries.to_h
  end

  def call
    grades = build_grades
    errors = {}

    Grade.transaction do
      grades.each { |grade| errors[grade.student_id] = grade.errors.full_messages unless grade.save }
      raise ActiveRecord::Rollback if errors.any?
    end

    Result.new(saved_count: errors.any? ? 0 : grades.size, errors: errors)
  end

  private

  def build_grades
    students = @evaluation.section.active_students.index_by(&:id)
    existing = @evaluation.grades.index_by(&:student_id)

    @entries.filter_map do |student_id, values|
      student = students[student_id.to_i]
      score = decimal(values[:score])
      grade = student && existing[student.id]
      next if student.nil? || score.blank? || (grade && !grade.rechazada?)

      attributes = { entered_by: @author, status: "pendiente", score: score, feedback: values[:feedback].presence,
                     points: decimal(values[:points]).presence }
      grade ? grade.tap { |rejected| rejected.assign_attributes(attributes) } : Grade.new(evaluation: @evaluation, student: student, **attributes)
    end
  end

  # "5,5" → "5.5": in Chile grades are written with a decimal comma.
  def decimal(value)
    value.to_s.strip.tr(",", ".")
  end
end
