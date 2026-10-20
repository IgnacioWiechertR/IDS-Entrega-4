class AddUniversityToDomainTables < ActiveRecord::Migration[8.1]
  # table => [parent table, foreign key to the parent]. Order matters for the backfill:
  # evaluations and attendance_sessions get their university before grades and attendance_records.
  PARENTS = {
    course_coordinators: [ :courses, :course_id ],
    section_staffs: [ :sections, :section_id ],
    enrollments: [ :sections, :section_id ],
    evaluations: [ :sections, :section_id ],
    attendance_sessions: [ :sections, :section_id ],
    grades: [ :evaluations, :evaluation_id ],
    attendance_records: [ :attendance_sessions, :attendance_session_id ],
    notifications: [ :users, :recipient_id ]
  }.freeze

  def up
    PARENTS.each_key { |table| add_reference table, :university, foreign_key: true }

    PARENTS.each do |table, (parent, foreign_key)|
      execute <<~SQL.squish
        UPDATE #{table} SET university_id = #{parent}.university_id
        FROM #{parent} WHERE #{parent}.id = #{table}.#{foreign_key}
      SQL
    end

    PARENTS.each_key { |table| change_column_null table, :university_id, false }
  end

  def down
    PARENTS.each_key { |table| remove_reference table, :university, foreign_key: true }
  end
end
