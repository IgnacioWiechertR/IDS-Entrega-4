# Course and section overviews.
module OverviewHelper
  TAB_CLASSES = "rounded-md px-3 py-1.5 text-sm font-medium".freeze

  # 5.46 → "5,5"; "—" while there are no published grades.
  def grade_average(value)
    value ? number_with_precision(value, precision: 1) : "—"
  end

  # "2026-2 (01-08-2026 – 30-11-2026)": courses and sections always show their period.
  def term_period(term)
    "#{term.name} (#{l(term.starts_on)} – #{l(term.ends_on)})"
  end

  def section_professor(section)
    section.section_staffs.find { |staff| staff.role == "profesor" }&.user&.name || "Sin profesor"
  end

  def section_assistants(section)
    names = section.section_staffs.select { |staff| staff.role == "ayudante" }.map { |staff| staff.user.name }
    names.any? ? names.to_sentence : "Sin ayudantes"
  end

  def overview_tab(label, url, active)
    classes = active ? "bg-indigo-600 text-white" : "border border-slate-300 text-slate-700 hover:bg-slate-50"
    link_to label, url, class: "#{TAB_CLASSES} #{classes}", aria: { current: (active ? "page" : nil) }
  end
end
