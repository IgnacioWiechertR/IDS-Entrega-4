require "test_helper"

# C1: the ayudante enters the preliminary grades of an evaluation for the students enrolled in its section.
class GradeEntryServiceTest < ActiveSupport::TestCase
  setup do
    @evaluation = Evaluation.create!(section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @first = users(:alumno) # already enrolled in sections(:one)
    @second = User.create!(first_name: "Segunda", last_name: "Alumna", rut: "10000004-4", email: "segunda@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
    Enrollment.create!(section: sections(:one), student: @second)
  end

  def enter(entries, evaluation: @evaluation)
    GradeEntryService.new(evaluation: evaluation, author: users(:ayudante), entries: entries).call
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

  test "no toca la nota que un alumno ya tiene en la evaluación" do
    # grades(:one) is the pending grade of users(:alumno) in evaluations(:one).
    assert_no_difference -> { Grade.count } do
      result = enter({ @first.id.to_s => { score: "2.0" } }, evaluation: evaluations(:one))
      assert_equal 0, result.saved_count
    end
    assert_equal 5.5, grades(:one).reload.score
  end

  test "ignora a quien no está inscrito en la sección" do
    result = enter({ users(:profesor).id.to_s => { score: "6.0" } })

    assert_equal 0, result.saved_count
    assert_nil @evaluation.grades.find_by(student: users(:profesor))
  end
end
