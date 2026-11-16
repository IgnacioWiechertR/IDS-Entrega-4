# End-of-term summary of one university for the director's dashboard (D1).
#
# Everything is computed inside the university's own tenant, so a summary never mixes data of two universities
# even when the dashboard shows both side by side. The figures are read once, with a fixed number of queries,
# so the dashboard stays fast whatever the number of sections.
#
# - Period: the current term of the university or, without one, its most recent term. D2 lets the director pick
#   another term and narrow the summary to a faculty or a course; an id of another university is not found (404).
# - Final average of a student in a section: weighted average of their published grades, like the section
#   overview (SectionStatsService#student_average).
# - Average: mean of those final averages. Approved: final average >= 4.0; failed: below 4.0.
# - Attendance: classes attended / classes recorded, over the active students of every section with classes
#   (a class without a mark for the student counts as absent, like B8).
# - Grade records closed ("actas cerradas"): every active student has a published grade in every evaluation of
#   their section. While they are not, the approval and failure rates are not final and are not shown.
class UniversitySummaryService
  PASSING_GRADE = 4.0

  attr_reader :university, :term, :faculty, :course, :average, :approved_count, :failed_count, :attendance_percentage

  def initialize(university, term_id: nil, faculty_id: nil, course_id: nil)
    @university = university
    ActsAsTenant.with_tenant(university) do
      load_filters(term_id, faculty_id, course_id)
      load_figures
    end
  end

  def term? = term.present?

  # D2: the summary is narrowed to a faculty or a course.
  def filtered? = faculty.present? || course.present?

  # No active student in the sections of the summary, so there is nothing to show.
  def empty? = @enrolled_count.zero?

  def records_closed? = @records_closed

  # Students with a final average (one per student and section).
  def graded_count = approved_count + failed_count

  # Percentages of the graded students; nil while the grade records are open or nobody has a final average.
  def approval_rate = rate(approved_count)

  def failure_rate = rate(failed_count)

  private

  def rate(count)
    return unless records_closed? && graded_count.positive?

    count * 100.0 / graded_count
  end

  # Ids come from the request: find! keeps them inside the university, so one of another university is a 404.
  def load_filters(term_id, faculty_id, course_id)
    @term = term_id.present? ? Term.find(term_id) : Term.current_term || Term.order(starts_on: :desc, id: :desc).first
    @faculty = Faculty.find(faculty_id) if faculty_id.present?
    @course = Course.find(course_id) if course_id.present?
  end

  def load_figures
    enrollments = Enrollment.where(section_id: section_ids, active: true).pluck(:section_id, :student_id)
    @enrolled_count = enrollments.size

    load_grades(section_ids, enrollments)
    load_attendance(section_ids, enrollments)
  end

  def section_ids
    @section_ids ||= begin
      sections = term ? Section.where(term: term) : Section.none
      sections = sections.joins(:course).where(courses: { faculty_id: faculty.id }) if faculty
      sections = sections.where(course: course) if course
      sections.pluck(:id)
    end
  end

  def load_grades(section_ids, enrollments)
    evaluations = Evaluation.where(section_id: section_ids).pluck(:id, :section_id, :weight)
    section_of = evaluations.to_h { |id, section_id, _weight| [ id, section_id ] }
    weight_of = evaluations.to_h { |id, _section_id, weight| [ id, weight ] }
    published = Grade.publicada.where(evaluation_id: section_of.keys).pluck(:evaluation_id, :student_id, :score)
      .group_by { |evaluation_id, student_id, _score| [ section_of[evaluation_id], student_id ] }

    averages = enrollments.filter_map do |enrollment|
      grades = published[enrollment]
      next unless grades

      grades.sum { |evaluation_id, _student_id, score| score * weight_of[evaluation_id] } /
        grades.sum { |evaluation_id, _student_id, _score| weight_of[evaluation_id] }
    end

    @average = averages.sum / averages.size if averages.any?
    @approved_count = averages.count { |average| average >= PASSING_GRADE }
    @failed_count = averages.size - approved_count
    @records_closed = all_grades_published?(enrollments, evaluations, published)
  end

  # Closed when there is at least one grade to give and every active student has all of theirs published.
  def all_grades_published?(enrollments, evaluations, published)
    evaluations_per_section = evaluations.map(&:second).tally
    expected = enrollments.sum { |section_id, _student_id| evaluations_per_section.fetch(section_id, 0) }
    given = enrollments.sum { |enrollment| published.fetch(enrollment, []).size }

    expected.positive? && given == expected
  end

  def load_attendance(section_ids, enrollments)
    sessions_per_section = AttendanceSession.where(section_id: section_ids).group(:section_id).count
    recorded = enrollments.sum { |section_id, _student_id| sessions_per_section.fetch(section_id, 0) }
    return if recorded.zero?

    active = enrollments.to_set
    present = AttendanceRecord.presente.joins(:attendance_session)
      .where(attendance_sessions: { section_id: section_ids })
      .pluck("attendance_sessions.section_id", :student_id)
      .count { |enrollment| active.include?(enrollment) }

    @attendance_percentage = present * 100.0 / recorded
  end
end
