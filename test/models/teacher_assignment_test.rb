require "test_helper"
require_relative "../support/teacher_assignment_data"

class TeacherAssignmentTest < ActiveSupport::TestCase
  include TeacherAssignmentData

  setup do
    prepare_teacher_assignment_data
    # The validations read the section's course and term, which are scoped by university (A3).
    ActsAsTenant.current_tenant = @university
  end

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
    @section.update_columns(course_id: @other_section.course_id)
    assignment = professor_assignment

    assert_not @section.valid?
    assert @section.errors[:course].any?
  end

  test "rechaza secciones cuyo período pertenece a otra universidad" do
    @section.update_columns(term_id: @other_section.term_id)
    assignment = professor_assignment

    assert_not @section.valid?
    assert @section.errors[:term].any?
  end

  test "una asignación de ayudante puede coexistir con la del profesor" do
    professor_assignment.save!

    assert professor_assignment(user: @assistant, role: "ayudante").save
  end

  test "universidades diferentes pueden tener cada una su profesor asignado" do
    professor_assignment.save!

    ActsAsTenant.with_tenant(@other_university) do
      assert professor_assignment(section: @other_section, user: @other_professor, assigned_by: @other_admin).save
    end
  end

  test "el coordinador asigna un profesor en una sección de su asignatura y período" do
    prepare_coordinator_data
    assignment = professor_assignment(assigned_by: @coordinator)

    assert assignment.save, assignment.errors.full_messages.join(", ")
    assert_equal @coordinator, assignment.reload.assigned_by
  end

  test "el coordinador puede asignarse a sí mismo" do
    prepare_coordinator_data

    assert professor_assignment(user: @coordinator, assigned_by: @coordinator).save
  end

  test "el coordinador no asigna en otro período ni en otra asignatura" do
    prepare_coordinator_data

    [ @other_term_section, @other_course_section ].each do |section|
      assignment = professor_assignment(section: section, assigned_by: @coordinator)

      assert_not assignment.valid?
      assert_includes assignment.errors[:assigned_by],
        "debe ser un administrativo de la universidad o el coordinador de la asignatura"
    end
  end

  test "una coordinación que cruza universidades no autoriza a asignar" do
    prepare_coordinator_data
    create_cross_university_coordination

    ActsAsTenant.with_tenant(@other_university) do
      assignment = professor_assignment(section: @other_section, user: @other_professor, assigned_by: @coordinator)

      assert_not assignment.valid?
      assert assignment.errors[:assigned_by].any?
    end
  end

  test "las secciones coordinadas son las de la asignatura en el período que coordina" do
    prepare_coordinator_data

    assert_equal [ @section ], Section.coordinated_by(@coordinator).to_a
    assert_empty Section.coordinated_by(@professor)
    assert_empty Section.coordinated_by(@director)
    assert @section.coordinated_by?(@coordinator)
    assert_not @other_term_section.coordinated_by?(@coordinator)
    assert_not @other_course_section.coordinated_by?(@coordinator)
    assert_not @section.coordinated_by?(@professor)
  end

  test "las secciones coordinadas ignoran coordinaciones que cruzan universidades" do
    prepare_coordinator_data
    create_cross_university_coordination

    ActsAsTenant.with_tenant(@other_university) do
      assert_empty Section.coordinated_by(@coordinator)
      assert_not @other_section.coordinated_by?(@coordinator)
    end
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
