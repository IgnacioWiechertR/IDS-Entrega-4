class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :university, null: true, foreign_key: true
      t.string :email
      t.string :rut
      t.string :first_name
      t.string :last_name
      t.boolean :active

      t.timestamps
    end
  end
end
