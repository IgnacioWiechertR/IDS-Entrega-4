class CreateFaculties < ActiveRecord::Migration[8.1]
  def change
    create_table :faculties do |t|
      t.references :university, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
