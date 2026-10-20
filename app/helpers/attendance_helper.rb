module AttendanceHelper
  STATUS_LABELS = { "presente" => "Presente", "ausente" => "Ausente" }.freeze

  def section_title(section)
    "#{section.course.code} #{section.course.name} · Sección #{section.number} (#{section.term.name})"
  end

  # "Aún sin clases" while nothing has been recorded, instead of 0 % (B8).
  def attendance_percentage(percentage)
    percentage ? number_to_percentage(percentage, precision: 0) : "Aún sin clases"
  end

  def attendance_status_label(status)
    STATUS_LABELS.fetch(status, "Sin marca")
  end

  def attendance_status_classes(status)
    case status
    when "presente" then "bg-emerald-50 text-emerald-700"
    when "ausente" then "bg-red-50 text-red-700"
    else "text-slate-400"
    end
  end
end
