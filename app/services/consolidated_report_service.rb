require "csv"

class ConsolidatedReportService
  Row = Data.define(
    :section, :course, :term, :professor_name,
    :evaluations_count, :has_evaluations,
    :average_grade, :pass_rate, :fail_rate,
    :max_grade, :min_grade, :attendance_rate
  )

  CSV_HEADERS = [
    "Codigo",
    "Asignatura",
    "Seccion",
    "Periodo",
    "Profesor",
    "Promedio",
    "% Aprobados",
    "% Reprobados",
    "Nota maxima",
    "Nota minima",
    "% Asistencia"
  ].freeze

  def self.call(university:, term_id: nil, course_id: nil)
    new(university:, term_id:, course_id:).call
  end

  def self.to_csv(rows)
    CSV.generate(col_sep: ";") do |csv|
      csv << CSV_HEADERS
      rows.each do |row|
        csv << [
          row.course.code,
          row.course.name,
          row.section.number,
          row.term.name,
          row.professor_name,
          format_decimal(row.average_grade),
          format_percent(row.pass_rate),
          format_percent(row.fail_rate),
          format_decimal(row.max_grade),
          format_decimal(row.min_grade),
          format_percent(row.attendance_rate)
        ]
      end
    end
  end

  def self.format_decimal(value)
    value ? format("%.1f", value) : "Sin datos"
  end

  def self.format_percent(value)
    value ? "#{format('%.1f', value)}%" : "Sin datos"
  end

  def initialize(university:, term_id: nil, course_id: nil)
    @university = university
    @term_id = term_id
    @course_id = course_id
  end

  def call
    return [] unless @university

    sections = Section.where(university_id: @university.id)
                      .includes(:course, :term, section_staffs: :user)
                      .joins(:course, :term)
                      .order("terms.starts_on DESC, courses.code ASC, sections.number ASC")

    sections = sections.where(term_id: @term_id) if @term_id.present?
    sections = sections.where(course_id: @course_id) if @course_id.present?

    section_ids = sections.map(&:id)
    return [] if section_ids.empty?

    eval_counts = Evaluation.where(section_id: section_ids).group(:section_id).count
    active_enrollments = Enrollment.where(section_id: section_ids, active: true)
                                   .pluck(:section_id, :student_id)
                                   .group_by(&:first)
                                   .transform_values { |pairs| pairs.map(&:last).to_set }

    grades_by_section = Grade.joins(:evaluation)
                             .where(evaluations: { section_id: section_ids }, status: "publicada")
                             .pluck("evaluations.section_id", :student_id, :score, "evaluations.weight")
                             .group_by(&:first)

    sessions_count = AttendanceSession.where(section_id: section_ids).group(:section_id).count
    attended_count = AttendanceRecord.joins(:attendance_session)
                                     .where(attendance_sessions: { section_id: section_ids }, status: %w[presente justificado])
                                     .group("attendance_sessions.section_id")
                                     .count

    sections.map do |section|
      build_row(
        section:,
        evaluations_count: eval_counts.fetch(section.id, 0),
        active_student_ids: active_enrollments.fetch(section.id, Set.new),
        grade_tuples: grades_by_section.fetch(section.id, []),
        total_sessions: sessions_count.fetch(section.id, 0),
        attended_records: attended_count.fetch(section.id, 0)
      )
    end
  end

  private

  def build_row(section:, evaluations_count:, active_student_ids:, grade_tuples:, total_sessions:, attended_records:)
    professor = section.section_staffs.find { |s| s.role == "profesor" }&.user
    has_evaluations = evaluations_count.positive?

    student_averages = compute_student_averages(grade_tuples, active_student_ids)

    if has_evaluations && student_averages.any?
      average_grade = (student_averages.sum / student_averages.size).round(1)
      approved_count = student_averages.count { |avg| avg >= 4.0 }
      pass_rate = ((approved_count.to_f / student_averages.size) * 100).round(1)
      fail_rate = (100.0 - pass_rate).round(1)
      max_grade = student_averages.max.round(1)
      min_grade = student_averages.min.round(1)
    end

    expected_marks = total_sessions * active_student_ids.size
    attendance_rate = expected_marks.positive? ? ((attended_records.to_f / expected_marks) * 100).round(1) : nil

    Row.new(
      section:,
      course: section.course,
      term: section.term,
      professor_name: professor&.name || "Sin profesor asignado",
      evaluations_count:,
      has_evaluations:,
      average_grade:,
      pass_rate:,
      fail_rate:,
      max_grade:,
      min_grade:,
      attendance_rate:
    )
  end

  def compute_student_averages(grade_tuples, active_student_ids)
    by_student = grade_tuples.select { |(_, student_id, _, _)| active_student_ids.include?(student_id) }
                             .group_by { |(_, student_id, _, _)| student_id }

    by_student.values.filter_map do |tuples|
      total_weight = tuples.sum { |(_, _, _, weight)| weight.to_d }
      next if total_weight <= 0

      weighted_sum = tuples.sum { |(_, _, score, weight)| score.to_d * weight.to_d }
      (weighted_sum / total_weight).to_f
    end
  end
end
