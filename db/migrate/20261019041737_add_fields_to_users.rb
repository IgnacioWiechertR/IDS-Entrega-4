class AddFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string
    # add_column :users, :rut, :string
    add_column :users, :role, :integer
  end
end
