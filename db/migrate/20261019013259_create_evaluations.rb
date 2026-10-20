class CreateEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :evaluations do |t|
      t.references :section, null: false, foreign_key: true
      t.string :name
      t.decimal :weight, precision: 5, scale: 2
      t.date :due_on
      t.text :rubric

      t.timestamps
    end
  end
end
