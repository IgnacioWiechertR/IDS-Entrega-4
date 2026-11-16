require "test_helper"
require_relative "../support/coordinator_assignment_data"

class CoordinatorAssignmentTest < ActiveSupport::TestCase
  include CoordinatorAssignmentData

  setup do
    prepare_coordinator_assignment_data
    ActsAsTenant.current_tenant = @university
  end
  teardown { ActsAsTenant.current_tenant = nil }

  test "el administrativo asigna un profesor de su universidad y queda registrado" do
    assignment = coordinator_assignment

    assert assignment.save, assignment.errors.full_messages.join(", ")
    assert_equal @admin, assignment.reload.assigned_by
  end

  test "el director puede asignar en ambas universidades" do
    assert coordinator_assignment(assigned_by: @director).save

    ActsAsTenant.with_tenant(@other_university) do
      assignment = coordinator_assignment(university: @other_university, course: @other_course,
        term: @other_term, user: @other_professor, assigned_by: @director)
      assert assignment.save, assignment.errors.full_messages.join(", ")
    end
  end

  test "rechaza al administrativo de otra universidad" do
    assignment = coordinator_assignment(assigned_by: @other_admin)

    assert_not assignment.valid?
    assert assignment.errors[:assigned_by].any?
  end

  test "los demás roles no pueden figurar como autores de la asignación" do
    [ @professor, @assistant, @student ].each do |actor|
      assignment = coordinator_assignment(assigned_by: actor)

      assert_not assignment.valid?
      assert assignment.errors[:assigned_by].any?
    end
  end

  test "el coordinador debe tener una cuenta de profesor" do
    [ @admin, @assistant, @student, @director ].each do |user|
      assignment = coordinator_assignment(user: user)

      assert_not assignment.valid?
      assert assignment.errors[:user].any?
    end
  end

  test "rechaza un profesor de otra universidad" do
    assignment = coordinator_assignment(user: @other_professor)

    assert_not assignment.valid?
    assert assignment.errors[:user].any?
  end

  test "rechaza períodos de otra universidad" do
    assignment = coordinator_assignment(term: @other_term)

    assert_not assignment.valid?
    assert assignment.errors[:term].any?
  end

  test "se conserva el historial de asignaciones en períodos diferentes" do
    coordinator_assignment.save!

    assert coordinator_assignment(term: @past_term, user: @second_professor).save
  end
end
