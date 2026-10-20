class CreateAttendanceRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :attendance_records do |t|
      t.references :attendance_session, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.string :status

      t.timestamps
    end
  end
end
