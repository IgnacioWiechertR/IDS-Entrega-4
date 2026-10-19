class MakeEnrollmentsActiveByDefault < ActiveRecord::Migration[8.1]
  def change
    # An enrollment is active unless it is explicitly deactivated; existing NULLs become active.
    change_column_default :enrollments, :active, from: nil, to: true
    change_column_null :enrollments, :active, false, true
  end
end
