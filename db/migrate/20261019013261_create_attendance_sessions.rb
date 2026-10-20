class CreateAttendanceSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :attendance_sessions do |t|
      t.references :section, null: false, foreign_key: true
      t.date :held_on
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
