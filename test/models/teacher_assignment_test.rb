require "test_helper"
require_relative "../support/teacher_assignment_data"

class TeacherAssignmentTest < ActiveSupport::TestCase
  include TeacherAssignmentData

  setup { prepare_teacher_assignment_data }

  test "el administrativo asigna un profesor de su universidad" do
    assignment = professor_assignment

    assert assignment.save, assignment.errors.full_messages.join(", ")
    assert_equal @admin, assignment.reload.assigned_by
  end

  test "rechaza una segunda asignación del mismo profesor" do
    professor_assignment.save!

    assert_not professor_assignment.valid?
  end

  test "rechaza otro profesor cuando la sección ya tiene uno" do
    professor_assignment.save!
    assignment = professor_assignment(user: @second_professor)

    assert_not assignment.valid?
    assert_includes assignment.errors[:section_id], "ya tiene un profesor asignado"
  end

  test "rechaza profesores de otra universidad" do
    assignment = professor_assignment(user: @other_professor)

    assert_not assignment.valid?
    assert assignment.errors[:user].any?
  end

  test "rechaza usuarios que no son profesores" do
    [ @student, @assistant, @admin, @director ].each do |user|
      assignment = professor_assignment(user: user)

      assert_not assignment.valid?, "No debería aceptar el rol #{user.role}"
      assert_includes assignment.errors[:user], "debe tener el rol de profesor"
    end
  end

  test "rechaza asignaciones hechas por otros roles" do
    [ @professor, @assistant, @student, @director ].each do |actor|
      assignment = professor_assignment(assigned_by: actor)

      assert_not assignment.valid?
      assert assignment.errors[:assigned_by].any?
    end
  end

  test "rechaza al administrativo de otra universidad" do
    assignment = professor_assignment(assigned_by: @other_admin)

    assert_not assignment.valid?
    assert assignment.errors[:assigned_by].any?
  end

  test "rechaza secciones cuya asignatura pertenece a otra universidad" do
    @section.course = @other_section.course

    assert_not @section.valid?
    assert @section.errors[:course].any?
  end

  test "rechaza secciones cuyo período pertenece a otra universidad" do
    @section.term = @other_section.term

    assert_not @section.valid?
    assert @section.errors[:term].any?
  end

  test "una asignación de ayudante puede coexistir con la del profesor" do
    professor_assignment.save!

    assert professor_assignment(user: @assistant, role: "ayudante").save
  end

  test "universidades diferentes pueden tener cada una su profesor asignado" do
    professor_assignment.save!

    assert professor_assignment(section: @other_section, user: @other_professor, assigned_by: @other_admin).save
  end

  test "la base de datos impide dos profesores aunque se omitan las validaciones" do
    professor_assignment.save!

    assert_raises ActiveRecord::RecordNotUnique do
      SectionStaff.transaction(requires_new: true) do
        professor_assignment(user: @second_professor).save!(validate: false)
      end
    end

    assert_equal 1, SectionStaff.where(section: @section, role: "profesor").count
  end
end
