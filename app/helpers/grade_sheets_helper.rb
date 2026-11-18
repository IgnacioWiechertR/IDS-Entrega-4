module GradeSheetsHelper
  GRADE_STATUS_LABELS = {
    "pendiente" => "Pendiente de revisión",
    "rechazada" => "Rechazada",
    "publicada" => "Publicada"
  }.freeze

  def grade_status_label(grade) = GRADE_STATUS_LABELS.fetch(grade.status)

  # 5.5 → "5,5"
  def grade_score(grade) = number_with_precision(grade.score, precision: 1)

  # C14: 52.0 → "52", 52.5 → "52,5"
  def points_label(points) = number_with_precision(points, precision: 2, strip_insignificant_zeros: true)
end
