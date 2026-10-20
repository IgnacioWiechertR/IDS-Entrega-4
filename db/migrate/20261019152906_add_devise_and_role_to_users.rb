class AddDeviseAndRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :role, null: false, default: "alumno"

      ## Database authenticatable
      t.string :encrypted_password, null: false, default: ""

      ## Recoverable (columns ready for A2, the module is not enabled yet)
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      ## Rememberable
      t.datetime :remember_created_at

      ## Lockable
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_at
    end

    # Devise needs a non-null email; it must also be unique across both universities.
    change_column_default :users, :email, from: nil, to: ""
    change_column_null :users, :email, false, ""

    add_index :users, :email, unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, [ :university_id, :rut ], unique: true
  end
end
