require "test_helper"

# C11: the profesor and the ayudantes of a section see all its grades with their status
# (preliminar, rechazada u oficial). Nobody sees the grades of a section where they do not take part (404).
# The student's own official grades are C10 ("Mis notas").
class GradebooksTest < ActionDispatch::IntegrationTest
  setup do
    @section = sections(:one)
    @classmate = User.create!(first_name: "Compañera", last_name: "Curso", rut: "10000005-9", email: "companera@ucv.test",
      password: "password123", role: "alumno", university: universities(:ucv))
    ActsAsTenant.with_tenant(universities(:ucv)) { Enrollment.create!(section: @section, student: @classmate) }

    @control2 = Evaluation.create!(section: @section, name: "Control 2", weight: 20, due_on: Date.new(2026, 11, 5))
    @published = Grade.create!(evaluation: @control2, student: users(:alumno), score: 6.4, status: "publicada",
                               entered_by: users(:ayudante), reviewed_by: users(:profesor))
    @rejected = Grade.create!(evaluation: @control2, student: @classmate, score: 3.0, status: "rechazada",
                              rejection_comment: "Revisa la pregunta 2", entered_by: users(:ayudante))
  end

  def cell(grade) = "#cell_#{grade.student_id}_#{grade.evaluation_id}"

  test "el profesor ve todas las notas de la sección con su estado" do
    sign_in users(:profesor)
    get section_gradebook_path(@section)

    assert_response :success
    assert_select "th", text: evaluations(:one).name
    assert_select "th", text: "Control 2"
    assert_select cell(grades(:one)), text: /5,5.*Preliminar/m # pendiente
    assert_select cell(@published), text: /6,4.*Oficial/m
    assert_select cell(@rejected), text: /3,0.*Rechazada/m
  end

  test "el ayudante también ve las notas de su sección con su estado" do
    sign_in users(:ayudante)
    get section_gradebook_path(@section)

    assert_response :success
    assert_select cell(@rejected), text: /Rechazada/
  end

  test "una sección sin evaluaciones lo indica" do
    section = ActsAsTenant.with_tenant(universities(:ucv)) do
      Section.create!(course: courses(:one), term: terms(:one), number: 2).tap do |empty|
        other = User.create!(first_name: "Otro", last_name: "Profe", rut: "77777777-7", email: "otro.profe@ucv.test",
          password: "password123", role: "profesor", university: universities(:ucv))
        SectionStaff.create!(section: empty, user: other, role: "profesor", assigned_by: users(:administrativo))
        @other_professor = other
      end
    end
    sign_in @other_professor
    get section_gradebook_path(section)

    assert_select "#no-evaluations", text: /Esta sección aún no tiene evaluaciones/
  end

  test "quien no participa en la sección recibe 404, también el alumno inscrito" do
    other_professor = User.create!(first_name: "Otra", last_name: "Profesora", rut: "88888888-8", email: "otra.profesora@ucv.test",
      password: "password123", role: "profesor", university: universities(:ucv))

    [ users(:alumno), users(:administrativo), other_professor ].each do |user|
      sign_in user
      get section_gradebook_path(@section)
      assert_response :not_found, "#{user.email} no debería ver las notas de la sección"
    end
  end

  test "una sección de otra universidad responde 404" do
    sign_in users(:profesor_iusa)
    get section_gradebook_path(@section)

    assert_response :not_found
  end

  test "la lista de evaluaciones lleva a las notas de la sección al profesor y al ayudante" do
    %i[profesor ayudante].each do |fixture|
      sign_in users(fixture)
      get section_evaluations_path(@section)
      assert_select "a[href=?]", section_gradebook_path(@section), text: "Ver todas las notas"
      sign_out :user
    end
  end
end
