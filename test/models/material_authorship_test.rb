require "test_helper"
require_relative "../support/material_edit_data"

class MaterialAuthorshipTest < ActiveSupport::TestCase
  include MaterialEditData

  setup { prepare_material_edit_data }
  teardown { clear_material_edit_files }

  test "autor y curso son inmutables después de crear el material" do
    assert_raises(ActiveRecord::ReadonlyAttributeError) { @owned.uploaded_by_id = @peer.id }
    assert_raises(ActiveRecord::ReadonlyAttributeError) { @owned.course_id = courses(:three).id }
    assert_equal @professor.id, @owned.reload.uploaded_by_id
    assert_equal @course.id, @owned.course_id
  end

  test "el autor identificado debe ser profesor de la universidad correspondiente" do
    [ users(:profesor_iusa), users(:administrativo), users(:alumno) ].each do |author|
      material = Material.new(course: @course, uploaded_by: author, title: "Inválido",
        file: { io: StringIO.new(EDIT_PDF), filename: "guia.pdf" })
      assert_not material.valid?
      assert material.errors[:uploaded_by].any?
    end
  end

  test "los registros antiguos permanecen sin propietario y sin permiso de edición" do
    assert_nil materials(:one).uploaded_by
    assert Ability.new(@professor).cannot?(:update, materials(:one))
    assert Ability.new(users(:director)).cannot?(:update, materials(:one))
  end

  test "solo su autor con participación puede editar y no recibe permiso de eliminación" do
    assert Ability.new(@professor).can?(:update, @owned)
    assert Ability.new(@peer).cannot?(:update, @owned)
    assert Ability.new(@professor).cannot?(:update, @peer_material)
    assert MaterialEditPolicy.new(@professor).cannot?(:destroy, @owned)
    assert MaterialEditPolicy.new(@professor).cannot?(:create, Material)
  end

  test "no se elimina la cuenta que conserva la autoría de materiales" do
    assert_no_difference [ "User.count", "Material.count" ] do
      assert_not @peer.destroy
    end
    assert @peer.errors[:base].any?
    assert_equal @peer.id, @peer_material.reload.uploaded_by_id
  end

  test "50 MB son válidos y un byte adicional se rechaza sin guardar" do
    Tempfile.create([ "limite-b3", ".pdf" ]) do |file|
      file.binmode
      file.write(EDIT_PDF)
      [ 50_000_000, 50_000_001 ].each do |size|
        file.truncate(size)
        file.rewind
        material = Material.new(course: @course, uploaded_by: @professor, title: "Límite",
          file: { io: file, filename: "grande.pdf" })
        assert_equal(size == 50_000_000, material.valid?)
      end
    end
  end
end
