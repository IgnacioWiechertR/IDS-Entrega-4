require "test_helper"

# C1: the ayudante enters the preliminary grades of an evaluation for the students enrolled in its section.
class GradeEntryServiceTest < ActiveSupport::TestCase
  setup do
    @evaluation = Evaluation.create!(section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @first = users(:alumno) # already enrolled in sections(:one)
    @second = User.create!(first_name: "Segunda", last_name: "Alumna", rut: "10000004-0", email: "segunda@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
    Enrollment.create!(section: sections(:one), student: @second)
  end

  def enter(entries, evaluation: @evaluation, author: users(:ayudante))
    GradeEntryService.new(evaluation: evaluation, author: author, entries: entries).call
  end

  test "guarda las notas como preliminares, con el ayudante como autor" do
    result = enter({ @first.id.to_s => { score: "6.0", feedback: "Buen desarrollo", points: "48" },
                     @second.id.to_s => { score: "4.5" } })

    assert result.success?
    assert_equal 2, result.saved_count

    grade = @evaluation.grades.find_by!(student: @first)
    assert grade.pendiente?
    assert_equal users(:ayudante), grade.entered_by
    assert_equal "Buen desarrollo", grade.feedback
    assert_equal 48, grade.points
    assert_nil @evaluation.grades.find_by!(student: @second).feedback
  end

  test "acepta la coma decimal en la nota y el puntaje" do
    enter({ @first.id.to_s => { score: "5,5", points: "12,5" } })

    grade = @evaluation.grades.find_by!(student: @first)
    assert_equal 5.5, grade.score
    assert_equal 12.5, grade.points
  end

  test "una nota fuera de 1.0–7.0 no guarda ninguna nota del envío" do
    assert_no_difference -> { Grade.count } do
      result = enter({ @first.id.to_s => { score: "5.0" }, @second.id.to_s => { score: "7.5" } })

      assert_not result.success?
      assert_equal 0, result.saved_count
      assert_equal [ @second.id ], result.errors.keys
      assert_match "Nota", result.errors[@second.id].first
    end
  end

  test "una nota que no es un número tampoco se guarda" do
    result = enter({ @first.id.to_s => { score: "seis" } })

    assert_not result.success?
    assert result.errors[@first.id].any?
  end

  test "las filas sin nota no crean registro" do
    result = enter({ @first.id.to_s => { score: "", feedback: "pendiente de corregir" }, @second.id.to_s => { score: "6" } })

    assert result.success?
    assert_equal 1, result.saved_count
    assert_nil @evaluation.grades.find_by(student: @first)
  end

  # C3: the ayudante edits a pending grade before the profesor reviews it. grades(:one) is the pending 5.5 of
  # users(:alumno) in evaluations(:one).
  def pending_values(**changes)
    grade = grades(:one)
    { score: "5,5", feedback: grade.feedback, points: "" }.merge(changes)
  end

  test "edita una nota pendiente: sigue pendiente y queda como autor quien la editó" do
    other_assistant = User.create!(first_name: "Otro", last_name: "Ayudante", rut: "10000012-1", email: "otro.ayudante@ucv.test",
      password: "password123", role: "ayudante", university: universities(:ucv))
    SectionStaff.create!(section: sections(:one), user: other_assistant, role: "ayudante", assigned_by: users(:administrativo))

    result = enter({ @first.id.to_s => pending_values(score: "6,2") }, evaluation: evaluations(:one), author: other_assistant)

    assert result.success?
    assert_equal 1, result.saved_count
    grade = grades(:one).reload
    assert grade.pendiente?
    assert_equal 6.2, grade.score
    assert_equal other_assistant, grade.entered_by
  end

  test "cambiar solo el comentario o el puntaje también es una edición" do
    result = enter({ @first.id.to_s => pending_values(feedback: "Revisado de nuevo", points: "30") }, evaluation: evaluations(:one))

    assert_equal 1, result.saved_count
    assert_equal "Revisado de nuevo", grades(:one).reload.feedback
    assert_equal 30, grades(:one).points
  end

  test "una nota pendiente reenviada sin cambios no se toca ni cuenta" do
    before = grades(:one).updated_at

    result = enter({ @first.id.to_s => pending_values }, evaluation: evaluations(:one))

    assert result.success?
    assert_equal 0, result.saved_count
    assert_equal before, grades(:one).reload.updated_at
  end

  test "editar una pendiente fuera de 1.0–7.0 no guarda nada" do
    result = enter({ @first.id.to_s => pending_values(score: "0,5") }, evaluation: evaluations(:one))

    assert_not result.success?
    assert_equal 5.5, grades(:one).reload.score
  end

  test "dejar vacía la nota de una pendiente no la borra ni la cambia" do
    assert_no_difference -> { Grade.count } do
      result = enter({ @first.id.to_s => pending_values(score: "") }, evaluation: evaluations(:one))
      assert_equal 0, result.saved_count
    end
    assert_equal 5.5, grades(:one).reload.score
  end

  test "una nota publicada no se modifica aunque venga en el envío" do
    grades(:one).update_columns(status: "publicada")

    result = enter({ @first.id.to_s => pending_values(score: "2,0") }, evaluation: evaluations(:one))

    assert_equal 0, result.saved_count
    grade = grades(:one).reload
    assert grade.publicada?
    assert_equal 5.5, grade.score
  end

  # C7: the ayudante corrects the grades the profesor rejected and sends them again.
  def rejected_grade
    @rejected_grade ||= Grade.create!(evaluation: @evaluation, student: @first, score: 4.0, feedback: "Sin justificar",
      status: "rechazada", rejection_comment: "Revisa la pregunta 2", entered_by: users(:ayudante), reviewed_by: users(:profesor))
  end

  test "una nota rechazada corregida vuelve a pendiente, conservando el comentario del profesor" do
    grade = rejected_grade

    result = enter({ @first.id.to_s => { score: "5,0", feedback: "Pregunta 2 corregida", points: "40" } })

    assert result.success?
    assert_equal 1, result.saved_count
    grade.reload
    assert grade.pendiente?
    assert_equal 5.0, grade.score
    assert_equal "Pregunta 2 corregida", grade.feedback
    assert_equal "Revisa la pregunta 2", grade.rejection_comment
  end

  # C3 (decided on 17-nov): the sheet comes prefilled, so a rejected grade sent back unchanged is not a correction.
  test "una nota rechazada reenviada sin cambios se queda rechazada" do
    grade = rejected_grade

    result = enter({ @first.id.to_s => { score: "4,0", feedback: "Sin justificar", points: "" } })

    assert result.success?
    assert_equal 0, result.saved_count
    assert grade.reload.rechazada?
  end

  test "una nota rechazada que no viene en el envío se queda rechazada" do
    grade = rejected_grade

    result = enter({ @second.id.to_s => { score: "6.0" } })

    assert_equal 1, result.saved_count
    assert grade.reload.rechazada?
  end

  test "una corrección fuera de rango no guarda nada" do
    grade = rejected_grade

    result = enter({ @first.id.to_s => { score: "9" }, @second.id.to_s => { score: "6.0" } })

    assert_not result.success?
    assert grade.reload.rechazada?
    assert_equal 4.0, grade.score
    assert_nil @evaluation.grades.find_by(student: @second)
  end

  test "ignora a quien no está inscrito en la sección" do
    result = enter({ users(:profesor).id.to_s => { score: "6.0" } })

    assert_equal 0, result.saved_count
    assert_nil @evaluation.grades.find_by(student: users(:profesor))
  end
end
