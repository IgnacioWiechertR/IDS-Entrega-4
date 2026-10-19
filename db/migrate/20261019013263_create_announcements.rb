class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.references :course, null: false, foreign_key: true
      t.references :section, null: true, foreign_key: true
      t.string :subject
      t.text :body
      t.references :author, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
