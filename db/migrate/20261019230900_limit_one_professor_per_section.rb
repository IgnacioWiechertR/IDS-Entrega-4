class LimitOneProfessorPerSection < ActiveRecord::Migration[8.1]
  def change
    add_index :section_staffs, :section_id,
      unique: true,
      where: "role = 'profesor'",
      name: "index_section_staffs_one_professor_per_section"
  end
end
