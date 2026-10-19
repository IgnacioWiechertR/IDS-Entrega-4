class CreateGrades < ActiveRecord::Migration[8.1]
  def change
    create_table :grades do |t|
      t.references :evaluation, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.decimal :score, precision: 2, scale: 1
      t.string :status
      t.text :feedback
      t.text :rejection_comment
      t.references :entered_by, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
