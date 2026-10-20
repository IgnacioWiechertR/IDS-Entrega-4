module EvaluationsHelper
  # 20 → "20 %", 9.99 → "9,99 %"
  def weight_percentage(value)
    "#{number_with_precision(value, precision: 2, strip_insignificant_zeros: true)} %"
  end

  # Weight already assigned to the saved evaluations of the section.
  def assigned_weight(section)
    section.evaluations.sum(:weight)
  end
end
