# B11: announcements store the university of their course, like the other domain tables.
class AddUniversityToAnnouncements < ActiveRecord::Migration[8.1]
  def up
    add_reference :announcements, :university, foreign_key: true

    execute <<~SQL.squish
      UPDATE announcements SET university_id = courses.university_id
      FROM courses WHERE courses.id = announcements.course_id
    SQL

    change_column_null :announcements, :university_id, false
  end

  def down
    remove_reference :announcements, :university, foreign_key: true
  end
end
