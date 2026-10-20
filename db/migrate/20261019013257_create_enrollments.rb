class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :section, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.boolean :active

      t.timestamps
    end
  end
end
