class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.references :university, null: false, foreign_key: true
      t.references :faculty, null: false, foreign_key: true
      t.string :code
      t.string :name

      t.timestamps
    end
  end
end
