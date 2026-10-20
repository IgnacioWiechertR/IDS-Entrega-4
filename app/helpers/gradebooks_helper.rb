module GradebooksHelper
  # C11 uses the words of the card: preliminar (pending review), rechazada u oficial (published).
  GRADEBOOK_STATES = {
    "pendiente" => [ "Preliminar", "bg-amber-50 text-amber-800" ],
    "rechazada" => [ "Rechazada", "bg-red-50 text-red-700" ],
    "publicada" => [ "Oficial", "bg-emerald-50 text-emerald-700" ]
  }.freeze

  def gradebook_state_label(grade) = GRADEBOOK_STATES.fetch(grade.status).first

  def gradebook_state_classes(grade) = GRADEBOOK_STATES.fetch(grade.status).last
end
