class CreateTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :terms do |t|
      t.references :university, null: false, foreign_key: true
      t.string :name
      t.date :starts_on
      t.date :ends_on
      t.boolean :current

      t.timestamps
    end
  end
end
