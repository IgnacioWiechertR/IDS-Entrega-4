class CreateSectionStaffs < ActiveRecord::Migration[8.1]
  def change
    create_table :section_staffs do |t|
      t.references :section, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
