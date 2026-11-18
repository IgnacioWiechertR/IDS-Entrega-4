class AddUploadedByToMaterials < ActiveRecord::Migration[8.1]
  def change
    # Existing materials have no reliable author; do not infer one from course staff.
    add_reference :materials, :uploaded_by, null: true, foreign_key: { to_table: :users }
  end
end
