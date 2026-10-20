class CreateCourseCoordinators < ActiveRecord::Migration[8.1]
  def change
    create_table :course_coordinators do |t|
      t.references :course, null: false, foreign_key: true
      t.references :term, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
