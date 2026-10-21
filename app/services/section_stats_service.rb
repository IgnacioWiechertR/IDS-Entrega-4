# Overview of a section: its active students, their grades and attendance, and the section statistics
# (students, average of published grades and attendance %).
class SectionStatsService
  def initialize(section)
    @section = section
  end

  def attendance = @attendance ||= AttendanceCalculatorService.new(@section)

  # Students with an active enrollment, by last name.
  def students = attendance.students

  def evaluations = @evaluations ||= @section.evaluations.order(:due_on, :id).to_a

  # Every grade of the section (pendiente, rechazada and publicada), by student and evaluation.
  def grade(student, evaluation)
    grades[[ student.id, evaluation.id ]]
  end

  # Weighted average of the student's published grades: Σ(nota × ponderación) / Σ ponderación, over the evaluations
  # that already have a published grade. nil while there is none.
  def student_average(student)
    published = evaluations.filter_map do |evaluation|
      grade = grade(student, evaluation)
      [ grade.score, evaluation.weight ] if grade&.publicada?
    end
    return if published.empty?

    published.sum { |score, weight| score * weight } / published.sum { |_score, weight| weight }
  end

  # Average of the section: mean of the averages of the students that already have published grades.
  def average
    averages = students.filter_map { |student| student_average(student) }
    averages.sum / averages.size if averages.any?
  end

  # nil while no class has been recorded, so the views say so instead of showing 0 %.
  def student_attendance(student) = attendance.percentage(student)

  # Mean attendance % of the active students.
  def attendance_percentage
    return if students.empty? || attendance.sessions.empty?

    students.sum { |student| attendance.percentage(student) } / students.size
  end

  private

  def grades
    @grades ||= Grade.where(evaluation: evaluations).index_by { |grade| [ grade.student_id, grade.evaluation_id ] }
  end
end
