require "test_helper"

# C1: the ayudante of the section enters the preliminary grades of an evaluation and the profesor is notified.
class GradeSheetsTest < ActionDispatch::IntegrationTest
  setup do
    @section = sections(:one)
    @evaluation = Evaluation.create!(section: @section, name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @student = users(:alumno) # actively enrolled in sections(:one)
  end

  def sheet_path(evaluation = @evaluation) = edit_section_evaluation_grade_sheet_path(@section, evaluation)

  def submit(entries, evaluation = @evaluation)
    patch section_evaluation_grade_sheet_path(@section, evaluation), params: { entries: entries }
  end

  def second_student
    @second_student ||= User.create!(first_name: "Segunda", last_name: "Alumna", rut: "10000004-0", email: "segunda@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv)).tap do |student|
      ActsAsTenant.with_tenant(universities(:ucv)) { Enrollment.create!(section: @section, student: student) }
    end
  end

  test "el ayudante ve la planilla con los alumnos inscritos" do
    sign_in users(:ayudante)
    get sheet_path

    assert_response :success
    assert_select "h1", text: /Control 2/
    assert_select "#student_#{@student.id}", text: /#{@student.name}/
    assert_select "input[name=?]", "entries[#{@student.id}][score]"
  end

  test "el ayudante sube notas: quedan pendientes y se avisa al profesor" do
    sign_in users(:ayudante)

    assert_enqueued_with(job: GradeSubmissionNotificationJob, args: [ @evaluation, 1 ]) do
      submit(@student.id => { score: "5,5", feedback: "Buen desarrollo", points: "44" })
    end
    assert_redirected_to section_evaluations_path(@section)
    assert_equal "1 nota enviada a revisión.", flash[:notice]

    grade = @evaluation.grades.find_by!(student: @student)
    assert grade.pendiente?
    assert_equal 5.5, grade.score
    assert_equal users(:ayudante), grade.entered_by
  end

  test "una nota fuera de 1.0–7.0 no guarda ninguna y marca la fila" do
    second = second_student
    sign_in users(:ayudante)

    assert_no_difference -> { Grade.count } do
      assert_no_enqueued_jobs do
        submit(@student.id => { score: "6.0" }, second.id => { score: "8" })
      end
    end
    assert_response :unprocessable_content
    assert_select "[role=alert]", text: /No se guardó ninguna nota/
    assert_select "#student_#{second.id}", text: /Nota debe ser menor que o igual a 7\.0/
    assert_select "input[name=?][value=?]", "entries[#{@student.id}][score]", "6.0"
  end

  test "una nota oficial aparece en solo lectura" do
    # grades(:one): users(:alumno) has a 5.5 in evaluations(:one); here the profesor already published it.
    grades(:one).update_columns(status: "publicada")
    sign_in users(:ayudante)
    get sheet_path(evaluations(:one))

    assert_select "#student_#{@student.id}", text: /5,5.*Publicada/m
    assert_select "input[name=?]", "entries[#{@student.id}][score]", count: 0
  end

  test "sin notas ingresadas no se envía nada" do
    sign_in users(:ayudante)

    assert_no_enqueued_jobs do
      submit(@student.id => { score: "" })
    end
    assert_redirected_to sheet_path
    assert_equal "No hay notas nuevas ni cambios para enviar.", flash[:alert]
  end

  # C3: the ayudante edits a pending grade before the profesor reviews it. grades(:one) is the pending 5.5 of
  # users(:alumno) in evaluations(:one).
  def pending_entry(**changes)
    { @student.id => { score: "5,5", feedback: grades(:one).feedback, points: "" }.merge(changes) }
  end

  test "una nota pendiente aparece editable con sus valores actuales" do
    sign_in users(:ayudante)
    get sheet_path(evaluations(:one))

    assert_select "#student_#{@student.id}", text: /Pendiente de revisión/
    assert_select "input[name=?][value=?]", "entries[#{@student.id}][score]", "5,5"
    assert_select "input[name=?][value=?]", "entries[#{@student.id}][feedback]", grades(:one).feedback
  end

  test "el ayudante edita una nota pendiente: sigue pendiente y se avisa al profesor" do
    sign_in users(:ayudante)

    assert_enqueued_with(job: GradeSubmissionNotificationJob, args: [ evaluations(:one), 1 ]) do
      submit(pending_entry(score: "6,2"), evaluations(:one))
    end
    assert_redirected_to section_evaluations_path(@section)
    assert_equal "1 nota enviada a revisión.", flash[:notice]

    grade = grades(:one).reload
    assert grade.pendiente?
    assert_equal 6.2, grade.score
  end

  test "reenviar la planilla sin cambios no avisa al profesor" do
    sign_in users(:ayudante)

    assert_no_enqueued_jobs do
      submit(pending_entry, evaluations(:one))
    end
    assert_redirected_to sheet_path(evaluations(:one))
    assert_equal "No hay notas nuevas ni cambios para enviar.", flash[:alert]
  end

  test "una nota pendiente editada fuera de 1.0–7.0 no se guarda y marca la fila" do
    sign_in users(:ayudante)

    submit(pending_entry(score: "8"), evaluations(:one))

    assert_response :unprocessable_content
    assert_select "#student_#{@student.id}", text: /Nota debe ser menor que o igual a 7\.0/
    assert_equal 5.5, grades(:one).reload.score
  end

  test "una nota oficial no cambia aunque se envíe directamente" do
    grades(:one).update_columns(status: "publicada")
    sign_in users(:ayudante)

    submit(pending_entry(score: "2,0"), evaluations(:one))

    assert_equal 5.5, grades(:one).reload.score
    assert grades(:one).publicada?
  end

  test "el profesor, el alumno, el administrativo y el ayudante de otra sección no editan una nota pendiente" do
    other_assistant = User.create!(first_name: "Ayudante", last_name: "Otra sección", rut: "10000012-1",
      email: "otra.seccion@ucv.test", password: "password123", role: "ayudante", university: universities(:ucv))
    other_section = Section.create!(course: courses(:three), term: terms(:one), number: 1)
    SectionStaff.create!(section: other_section, user: other_assistant, role: "ayudante", assigned_by: users(:administrativo))

    [ users(:profesor), users(:alumno), users(:administrativo), other_assistant ].each do |user|
      sign_in user
      submit(pending_entry(score: "1,0"), evaluations(:one))

      assert_response :redirect
      assert_equal "No tienes permiso para ver esa página.", flash[:alert], "#{user.email} no debería editar"
      assert_equal 5.5, grades(:one).reload.score
      sign_out :user
    end
  end

  test "una sección sin matrículas activas no se puede enviar" do
    ActsAsTenant.with_tenant(universities(:ucv)) { enrollments(:one).update!(active: false) }
    sign_in users(:ayudante)

    get sheet_path
    assert_select "#no-students", text: /Sección sin matrículas activas/
    assert_select "input[type=submit][value=?][disabled]", "Subir a revisión"
  end

  test "el profesor, el alumno y el administrativo no ingresan notas" do
    %i[profesor alumno administrativo].each do |fixture|
      sign_in users(fixture)

      get sheet_path
      assert_response :redirect, "#{fixture} no debería abrir la planilla"
      assert_equal "No tienes permiso para ver esa página.", flash[:alert]

      assert_no_difference -> { Grade.count } do
        submit(@student.id => { score: "6.0" })
      end

      sign_out :user
    end
  end

  test "una sección de otra universidad responde 404" do
    sign_in users(:alumno_iusa)

    get sheet_path
    assert_response :not_found
  end

  # C7: the ayudante sees the rejected grades with the profesor's comment, corrects them and sends them again.
  def reject_grade
    Grade.create!(evaluation: @evaluation, student: @student, score: 4.0, feedback: "Sin justificar", status: "rechazada",
                  rejection_comment: "Revisa la pregunta 2", entered_by: users(:ayudante), reviewed_by: users(:profesor))
  end

  test "el ayudante ve la nota rechazada con el comentario del profesor, lista para corregir" do
    reject_grade
    sign_in users(:ayudante)
    get sheet_path

    assert_select "#student_#{@student.id}", text: /Rechazada por el profesor: «Revisa la pregunta 2»/
    assert_select "input[name=?][value=?]", "entries[#{@student.id}][score]", "4,0"
    assert_select "input[name=?][value=?]", "entries[#{@student.id}][feedback]", "Sin justificar"
  end

  test "al reenviar la nota corregida vuelve a pendiente y se avisa al profesor" do
    grade = reject_grade
    sign_in users(:ayudante)

    assert_enqueued_with(job: GradeSubmissionNotificationJob, args: [ @evaluation, 1 ]) do
      submit(@student.id => { score: "5,0", feedback: "Pregunta 2 corregida" })
    end
    assert_equal "1 nota enviada a revisión.", flash[:notice]
    assert grade.reload.pendiente?
    assert_equal 5.0, grade.score
  end

  test "la lista de evaluaciones avisa cuántas notas hay por corregir" do
    reject_grade
    sign_in users(:ayudante)
    get section_evaluations_path(@section)

    assert_select "a[href=?]", sheet_path, text: "Ingresar notas (1 por corregir)"
  end

  test "la lista de evaluaciones muestra Ingresar notas solo al ayudante" do
    sign_in users(:ayudante)
    get section_evaluations_path(@section)
    assert_select "a[href=?]", sheet_path, text: "Ingresar notas"
    sign_out :user

    sign_in users(:profesor)
    get section_evaluations_path(@section)
    assert_select "a[href=?]", sheet_path, count: 0
  end
end
