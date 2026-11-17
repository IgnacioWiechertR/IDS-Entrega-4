# C14: optional maximum score of an evaluation, to show "44 de 60" and convert a score to a grade.
class AddMaxPointsToEvaluations < ActiveRecord::Migration[8.1]
  def change
    add_column :evaluations, :max_points, :decimal, precision: 6, scale: 2
  end
end
