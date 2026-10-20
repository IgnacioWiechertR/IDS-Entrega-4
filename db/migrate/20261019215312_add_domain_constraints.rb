class AddDomainConstraints < ActiveRecord::Migration[8.1]
  REQUIRED_COLUMNS = {
    courses: %i[code name],
    sections: %i[number],
    terms: %i[name starts_on ends_on],
    evaluations: %i[name weight],
    grades: %i[score],
    section_staffs: %i[role],
    attendance_sessions: %i[held_on],
    attendance_records: %i[status],
    notifications: %i[kind message]
  }.freeze

  UNIQUE_INDEXES = {
    courses: %i[university_id code],
    sections: %i[course_id term_id number],
    course_coordinators: %i[course_id term_id],
    section_staffs: %i[section_id user_id],
    enrollments: %i[section_id student_id],
    grades: %i[evaluation_id student_id],
    attendance_sessions: %i[section_id held_on]
  }.freeze

  def change
    # Optional score of the evaluation (card C1: "y el puntaje").
    add_column :grades, :points, :decimal, precision: 6, scale: 2

    change_column_default :grades, :status, from: nil, to: "pendiente"
    change_column_null :grades, :status, false
    change_column_default :terms, :current, from: nil, to: false
    change_column_null :terms, :current, false

    REQUIRED_COLUMNS.each { |table, columns| columns.each { |column| change_column_null table, column, false } }

    UNIQUE_INDEXES.each { |table, columns| add_index table, columns, unique: true }
    add_index :attendance_records, %i[attendance_session_id student_id], unique: true,
              name: "index_attendance_records_on_session_and_student"
    add_index :terms, :university_id, unique: true, where: "current", name: "index_terms_on_university_id_current"
  end
end
