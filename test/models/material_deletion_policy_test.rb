require "test_helper"
require_relative "../support/material_deletion_data"

class MaterialDeletionPolicyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include MaterialDeletionData

  setup { prepare_material_deletion_data }
  teardown { clear_material_deletion_files }

  test "solo el autor con participación tiene permiso de eliminación" do
    assert Ability.new(@professor).can?(:destroy, @owned)
    assert Ability.new(@peer).cannot?(:destroy, @owned)
    assert Ability.new(@professor).cannot?(:destroy, @peer_material)
    assert Ability.new(@professor).cannot?(:destroy, materials(:one))
    assert Ability.new(@professor).cannot?(:destroy, @foreign)
  end

  test "otros roles no tienen permiso ni listado de eliminación" do
    %i[director administrativo ayudante alumno].each do |role|
      ability = Ability.new(users(role))
      assert ability.cannot?(:destroy, @owned), role.to_s
      assert ability.cannot?(:index, :material_deletions), role.to_s
    end
  end

  test "la política de B4 no concede subida edición o lectura global de materiales" do
    policy = MaterialDeletionPolicy.new(@professor)
    %i[create update read].each do |action|
      assert policy.cannot?(action, @owned), action.to_s
    end
  end

  test "el autor y el curso son inmutables y la migración no inventa autores" do
    assert_raises(ActiveRecord::ReadonlyAttributeError) { @owned.uploaded_by_id = @peer.id }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { @owned.course_id = courses(:three).id }
    assert_nil materials(:one).uploaded_by_id
    assert_equal @professor.id, @owned.reload.uploaded_by_id
  end
end
