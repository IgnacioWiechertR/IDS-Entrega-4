class AddSizeToUniversities < ActiveRecord::Migration[8.1]
  def change
    add_column :universities, :size, :string
  end
end
