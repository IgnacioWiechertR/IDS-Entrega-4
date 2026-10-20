class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.references :university, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :term, null: false, foreign_key: true
      t.integer :number

      t.timestamps
    end
  end
end
