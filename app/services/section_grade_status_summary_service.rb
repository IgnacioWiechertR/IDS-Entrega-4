class SectionGradeStatusSummaryService
  Row = Data.define(:section, :course, :term, :professor_name, :preliminares, :rechazadas, :oficiales, :total)

  def self.call(university:, term_id: nil)
    new(university:, term_id:).call
  end

  def initialize(university:, term_id: nil)
    @university = university
    @term_id = term_id
  end

  def call
    return [] unless @university

    sections = Section.where(university_id: @university.id)
                      .includes(:course, :term, section_staffs: :user)
                      .joins(:course, :term)
                      .order("terms.starts_on DESC, courses.code ASC, sections.number ASC")

    sections = sections.where(term_id: @term_id) if @term_id.present?

    counts_by_section_and_status = Grade.joins(evaluation: :section)
                                        .where(sections: { university_id: @university.id })
                                        .group("sections.id", "grades.status")
                                        .count

    sections.map do |section|
      preliminares = counts_by_section_and_status.fetch([ section.id, "pendiente" ], 0)
      rechazadas   = counts_by_section_and_status.fetch([ section.id, "rechazada" ], 0)
      oficiales    = counts_by_section_and_status.fetch([ section.id, "publicada" ], 0)
      professor    = section.section_staffs.find { |s| s.role == "profesor" }&.user

      Row.new(
        section:,
        course: section.course,
        term: section.term,
        professor_name: professor&.name || "Sin profesor asignado",
        preliminares:,
        rechazadas:,
        oficiales:,
        total: preliminares + rechazadas + oficiales
      )
    end
  end
end