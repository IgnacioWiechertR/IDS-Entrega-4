# C1: the ayudante enters the preliminary grades of an evaluation, all in one submission.
# C3: a pending grade is edited in the same submission and stays `pendiente`, with the editor as `entered_by`.
# C7: a grade the profesor rejected is corrected in the same submission and goes back to `pendiente` (its
# rejection comment is kept as history).
# The sheet comes prefilled, so an existing grade is only saved when its score, feedback or points change; an
# unchanged one (pending or rejected) is left as it is. Published grades are never touched.
# entries: { student_id => { score:, feedback:, points: } }. Rows without a score and students that are not
# actively enrolled in the section are skipped (an empty score never deletes a grade: that is C4).
# C14: when the evaluation has a maximum score, a row with a score and no grade gets the grade calculated from the
# score; a written grade always wins.
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
      points = decimal(values[:points]).presence
      # C14: without a written grade, it is calculated from the score when the evaluation has a maximum score.
      score = decimal(values[:score]).presence || converted(points)
      grade = student && existing[student.id]
      next if student.nil? || score.blank? || grade&.publicada?

      contents = { score: score, feedback: values[:feedback].presence, points: points }
      if grade
        edited(grade, contents)
      else
        Grade.new(evaluation: @evaluation, student: student, entered_by: @author, status: "pendiente", **contents)
      end
    end
  end

  # A preliminary grade (pending or rejected) with new contents, back to `pendiente`; nil when nothing changed.
  def edited(grade, contents)
    grade.assign_attributes(contents)
    return unless grade.will_save_change_to_score? || grade.will_save_change_to_feedback? || grade.will_save_change_to_points?

    grade.assign_attributes(entered_by: @author, status: "pendiente")
    grade
  end

  # C14 (DEC-18): the grade for a score, with a 50 % passing threshold, or nil without a maximum score or with a
  # score that is not a number. A score above the maximum is converted as the maximum, so the row shows only the
  # error of the score (Grade does not accept it) and not also one of the grade.
  def converted(points)
    max = @evaluation.max_points
    return unless max && points

    @evaluation.score_for([ BigDecimal(points), max ].min).to_s
  rescue ArgumentError
    nil
  end

  # "5,5" → "5.5": in Chile grades are written with a decimal comma.
  def decimal(value)
    value.to_s.strip.tr(",", ".")
  end
end
