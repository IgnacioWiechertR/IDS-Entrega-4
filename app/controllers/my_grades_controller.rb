# C10: the student sees their official (published) grades by course, and the detail of each correction.
# Everything is read from current_user, so another student's grade, an unpublished one or one from the other
# university (a different account) is a 404.
class MyGradesController < ApplicationController
  before_action { authorize! :read, :my_grades }

  def index
    @enrollments = current_user.enrollments.where(active: true).includes(section: %i[course term])
      .sort_by { |enrollment| [ enrollment.section.course.code, enrollment.section.number ] }
    @grades_by_section = published_grades.includes(:evaluation).order("evaluations.due_on", "evaluations.id")
      .group_by { |grade| grade.evaluation.section_id }
  end

  def show
    @grade = published_grades.includes(evaluation: { section: %i[course term] }).find(params.expect(:id))
  end

  private

  def published_grades = current_user.grades.publicada.joins(:evaluation)
end
