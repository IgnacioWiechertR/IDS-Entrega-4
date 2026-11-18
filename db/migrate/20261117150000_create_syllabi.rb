class CreateSyllabi < ActiveRecord::Migration[8.1]
  def change
    # One syllabus file per course and term (Entrega 2, "Rigidez del Syllabus": it is uploaded, never edited here).
    create_table :syllabi do |t|
      t.references :university, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :term, null: false, foreign_key: true
      # The account may be deleted later; the syllabus stays.
      t.references :uploaded_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :syllabi, %i[course_id term_id], unique: true
  end
end
