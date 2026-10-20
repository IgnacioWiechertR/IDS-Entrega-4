class AddUniqueIndexToUsersOnRutAndUniversity < ActiveRecord::Migration[8.1]
  def change
    # Agrega un índice único compuesto por rut y university_id
    add_index :users, [:rut, :university_id], unique: true
  end
end