# B7: a mark changed after it was saved keeps who corrected it and when.
class AddCorrectionToAttendanceRecords < ActiveRecord::Migration[8.1]
  def change
    add_reference :attendance_records, :corrected_by, foreign_key: { to_table: :users }
    add_column :attendance_records, :corrected_at, :datetime
  end
end
