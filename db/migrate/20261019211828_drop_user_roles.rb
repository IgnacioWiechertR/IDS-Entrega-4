class DropUserRoles < ActiveRecord::Migration[8.1]
  # The account role lives in users.role and the role in each course in section_staffs/enrollments,
  # so user_roles was never read. The block keeps the migration reversible.
  def change
    drop_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :role

      t.timestamps
    end
  end
end
