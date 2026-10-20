require "test_helper"

# The uniqueness rules are also backed by the database, so they hold even under concurrent requests.
class DomainConstraintsTest < ActiveSupport::TestCase
  UNIQUE_INDEXES = {
    courses: %i[university_id code],
    sections: %i[course_id term_id number],
    course_coordinators: %i[course_id term_id],
    section_staffs: %i[section_id user_id],
    enrollments: %i[section_id student_id],
    grades: %i[evaluation_id student_id],
    attendance_sessions: %i[section_id held_on],
    attendance_records: %i[attendance_session_id student_id]
  }.freeze

  REQUIRED_COLUMNS = {
    courses: %w[code name],
    sections: %w[number],
    terms: %w[name starts_on ends_on current],
    evaluations: %w[name weight],
    grades: %w[score status],
    section_staffs: %w[role],
    attendance_sessions: %w[held_on],
    attendance_records: %w[status],
    notifications: %w[kind message]
  }.freeze

  def connection = ActiveRecord::Base.connection

  test "las unicidades tienen índice único en la base de datos" do
    UNIQUE_INDEXES.each do |table, columns|
      assert connection.index_exists?(table, columns, unique: true), "falta el índice único #{table} #{columns}"
    end
  end

  test "solo puede haber un período vigente por universidad" do
    assert connection.index_exists?(:terms, :university_id, unique: true, where: "current")
  end

  test "las columnas obligatorias son NOT NULL" do
    REQUIRED_COLUMNS.each do |table, columns|
      columns.each { |column| assert_not connection.columns(table).find { |c| c.name == column }.null, "#{table}.#{column}" }
    end
  end

  test "la nota tiene puntaje opcional y estado pendiente por defecto" do
    columns = connection.columns(:grades).index_by(&:name)

    assert columns.fetch("points").null
    assert_equal "pendiente", columns.fetch("status").default
  end
end
