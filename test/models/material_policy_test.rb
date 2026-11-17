require "test_helper"
require_relative "../support/material_upload_data"

class MaterialPolicyTest < ActiveSupport::TestCase
  include MaterialUploadData

  setup do
    prepare_material_upload_data
    ActsAsTenant.current_tenant = @university
  end
  teardown { clear_uploaded_test_files }

  test "el profesor puede subir al curso donde enseña" do
    assert Ability.new(@professor).can?(:create, Material.new(course: @course))
  end

  test "una cuenta de profesor puede subir al curso que coordina" do
    assert Ability.new(@coordinator).can?(:create, Material.new(course: @coordinated_course))
  end

  test "no basta con ser profesor de la universidad si no participa en el curso" do
    assert Ability.new(@unassigned_professor).cannot?(:create, Material.new(course: @course))
  end

  test "otros roles no pueden subir aunque puedan administrar o consultar el curso" do
    [ @director, @admin, @assistant, @student ].each do |user|
      assert Ability.new(user).cannot?(:create, Material.new(course: @course)), user.role
    end
  end

  test "el profesor no puede subir a otra universidad" do
    assert Ability.new(@professor).cannot?(:create, Material.new(course: @other_course))
  end

  test "B1 no abre el scaffold global ni edición eliminación o lectura de materiales" do
    ability = Ability.new(@professor)
    %i[ index read update destroy ].each do |action|
      assert ability.cannot?(action, Material.new(course: @course)), action.to_s
    end
  end
end
