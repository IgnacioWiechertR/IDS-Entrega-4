require "test_helper"

class SectionGradeStatusSummaryServiceTest < ActiveSupport::TestCase
  setup do
    @ucv = universities(:ucv)
    @iusa = universities(:iusa)
    @admin = users(:administrativo)
    @ayudante = users(:ayudante)
    @profesor = users(:profesor)
    @alumno = users(:alumno)

    @term = Term.create!(
      university: @ucv,
      name: "2027-1",
      starts_on: Date.new(2027, 3, 1),
      ends_on: Date.new(2027, 7, 15)
    )
    @course = Course.create!(
      university: @ucv,
      faculty: faculties(:one),
      code: "D3TEST1",
      name: "Algoritmos"
    )
    @section = Section.create!(
      university: @ucv,
      course: @course,
      term: @term,
      number: 1
    )
    SectionStaff.create!(
      university: @ucv,
      section: @section,
      user: @profesor,
      role: "profesor",
      assigned_by: @admin
    )
  end

  test "cuenta notas preliminares, rechazadas y oficiales por sección y excluye otras universidades" do
    eval_pub = Evaluation.create!(university: @ucv, section: @section, name: "Control 1", weight: 30, due_on: Date.new(2027, 4, 10))
    eval_pen = Evaluation.create!(university: @ucv, section: @section, name: "Control 2", weight: 30, due_on: Date.new(2027, 5, 10))
    eval_rec = Evaluation.create!(university: @ucv, section: @section, name: "Control 3", weight: 40, due_on: Date.new(2027, 6, 10))

    extra_student = User.create!(
      first_name: "Ana", last_name: "Silva", rut: "10000031-8",
      email: "ana.d3@ucv.test", role: "alumno", university: @ucv, password: "password123"
    )

    Grade.create!(university: @ucv, evaluation: eval_pub, student: @alumno, score: 5.5, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)
    Grade.create!(university: @ucv, evaluation: eval_pub, student: extra_student, score: 6.0, status: "publicada", entered_by: @ayudante, reviewed_by: @profesor)
    Grade.create!(university: @ucv, evaluation: eval_pen, student: @alumno, score: 4.5, status: "pendiente", entered_by: @ayudante)
    Grade.create!(university: @ucv, evaluation: eval_rec, student: @alumno, score: 3.2, status: "rechazada", rejection_comment: "Revisar pauta", entered_by: @ayudante, reviewed_by: @profesor)

    iusa_section = ActsAsTenant.with_tenant(@iusa) do
      iusa_faculty = Faculty.first!
      iusa_term = Term.create!(university: @iusa, name: "2027-1", starts_on: Date.new(2027, 3, 1), ends_on: Date.new(2027, 7, 15))
      iusa_course = Course.create!(university: @iusa, faculty: iusa_faculty, code: "IUSA999", name: "Curso Externo")
      Section.create!(university: @iusa, course: iusa_course, term: iusa_term, number: 1)
    end

    rows = SectionGradeStatusSummaryService.call(university: @ucv, term_id: @term.id)

    assert_equal 1, rows.size
    row = rows.first
    assert_equal @section.id, row.section.id
    assert_equal @profesor.name, row.professor_name
    assert_equal 1, row.preliminares
    assert_equal 1, row.rechazadas
    assert_equal 2, row.oficiales
    assert_equal 4, row.total
    assert_not_includes rows.map { |r| r.section.id }, iusa_section.id
  end

  test "devuelve ceros cuando la sección no tiene evaluaciones ni notas" do
    rows = SectionGradeStatusSummaryService.call(university: @ucv, term_id: @term.id)
    row = rows.find { |r| r.section.id == @section.id }

    assert_not_nil row
    assert_equal [ 0, 0, 0, 0 ], [ row.preliminares, row.rechazadas, row.oficiales, row.total ]
  end
end
