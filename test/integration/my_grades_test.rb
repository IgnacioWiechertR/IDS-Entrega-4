require "test_helper"

# C10: the student sees, by course, their official (published) grades and the detail of each correction.
class MyGradesTest < ActionDispatch::IntegrationTest
  setup do
    @evaluation = Evaluation.create!(section: sections(:one), name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5),
                                     rubric: "Pregunta 1: 3 puntos. Pregunta 2: 4 puntos.")
    @published = Grade.create!(evaluation: @evaluation, student: users(:alumno), score: 6.2, points: 52, feedback: "Muy buen desarrollo",
                               status: "publicada", entered_by: users(:ayudante), reviewed_by: users(:profesor))
  end

  test "el alumno ve por asignatura cada evaluación con su nota y su ponderación" do
    sign_in users(:alumno)
    get my_grades_path

    assert_response :success
    assert_select "#section_#{sections(:one).id}", text: /ICC1001.*Programación/m
    assert_select "#grade_#{@published.id}", text: /Control 2.*20 %.*6,2/m
  end

  test "solo ve notas publicadas y solo las suyas" do
    # grades(:one) is a pending grade of users(:alumno); a classmate also has a published grade.
    classmate = User.create!(first_name: "Compañera", last_name: "Curso", rut: "10000005-5", email: "companera@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
    ActsAsTenant.with_tenant(universities(:ucv)) { Enrollment.create!(section: sections(:one), student: classmate) }
    other = Grade.create!(evaluation: @evaluation, student: classmate, score: 3.1, status: "publicada", entered_by: users(:ayudante))
    sign_in users(:alumno)

    get my_grades_path
    assert_select "#grade_#{grades(:one).id}", count: 0
    assert_select "#grade_#{other.id}", count: 0
    assert_no_match(/3,1/, response.body)
  end

  test "sin notas publicadas se muestra un mensaje" do
    @published.destroy!
    sign_in users(:alumno)
    get my_grades_path

    assert_select "#no-grades", text: /Aún no tienes notas publicadas/
    assert_select "table", count: 0
  end

  test "el detalle muestra la pauta, el puntaje y el comentario en solo lectura" do
    sign_in users(:alumno)
    get my_grade_path(@published)

    assert_response :success
    assert_select "h1", text: /Control 2/
    assert_select "#grade-score", text: /6,2/
    assert_select "#grade-points", text: /52/
    assert_select "#grade-feedback", text: /Muy buen desarrollo/
    assert_select "#evaluation-rubric", text: /Pregunta 1: 3 puntos/
    assert_select "main form", count: 0 # read only (the top bar has the sign-out form)
  end

  test "sin pauta ni comentario se muestra un mensaje predeterminado" do
    @evaluation.update!(rubric: nil)
    @published.update!(feedback: nil)
    sign_in users(:alumno)
    get my_grade_path(@published)

    assert_select "#no-correction", text: /El profesor no dejó pauta ni comentarios para esta evaluación/
  end

  test "una nota ajena, no publicada o de otra universidad responde 404" do
    sign_in users(:alumno)
    get my_grade_path(grades(:one)) # pending
    assert_response :not_found

    # An error page does not write the session cookie, so sign in again for the next request.
    sign_in users(:alumno_iusa)
    get my_grade_path(@published) # someone else's grade, in another university
    assert_response :not_found
  end

  test "el menú muestra Mis notas a los alumnos, y otras cuentas no tienen la vista" do
    sign_in users(:alumno)
    get my_grades_path
    assert_select "nav a[href=?]", my_grades_path, text: "Mis notas"
    sign_out :user

    %i[profesor administrativo].each do |fixture|
      sign_in users(fixture)
      get my_grades_path
      assert_response :redirect, "#{fixture} no debería tener Mis notas"
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]
      sign_out :user
    end
  end
end
