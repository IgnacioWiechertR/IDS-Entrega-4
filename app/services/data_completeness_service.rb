class DataCompletenessService
  Row = Data.define(:section, :issues)

  def self.call(university:)
    return [] unless university

    sections = Section.where(university_id: university.id).includes(:course, :term).order(:course_id, :number)
    ids = sections.map(&:id)
    professors = SectionStaff.where(section_id: ids, role: "profesor").pluck(:section_id).to_set
    students = Enrollment.where(section_id: ids, active: true).pluck(:section_id, :student_id)
      .group_by(&:first).transform_values { |pairs| pairs.map(&:last).to_set }
    attendance = AttendanceRecord.joins(:attendance_session)
      .where(attendance_sessions: { section_id: ids }).distinct.pluck("attendance_sessions.section_id").to_set
    evaluations = Evaluation.where(section_id: ids).pluck(:section_id, :id).group_by(&:first)
    published = Grade.where(evaluation_id: evaluations.values.flatten(1).map(&:last), status: "publicada")
      .pluck(:evaluation_id, :student_id).group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last).to_set }

    sections.filter_map do |section|
      issues = []
      active_students = students.fetch(section.id, Set.new)
      issues << "Sin profesor asignado" unless professors.include?(section.id)
      issues << "Sin alumnos activos" if active_students.empty?
      issues << "Sin asistencia registrada" unless attendance.include?(section.id)
      incomplete = evaluations.fetch(section.id, []).count do |_, evaluation_id|
        official_students = published.fetch(evaluation_id, Set.new)
        official_students.empty? || !(active_students - official_students).empty?
      end
      issues << "Evaluaciones con notas oficiales incompletas: #{incomplete}" if incomplete.positive?
      Row.new(section: section, issues: issues) if issues.any?
    end
  end
end
