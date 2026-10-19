require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attributes)
    User.new({ first_name: "Persona", last_name: "Nueva", rut: "66666666-6", email: "nueva@ucv.test",
               password: "password123", role: "alumno", university: universities(:ucv) }.merge(attributes))
  end

  test "un alumno con universidad es válido" do
    assert build_user.valid?
  end

  test "nombre, apellido y RUT son obligatorios" do
    user = build_user(first_name: "", last_name: "", rut: "")

    assert_not user.valid?
    %i[first_name last_name rut].each { |attribute| assert user.errors.added?(attribute, :blank) }
  end

  test "el director no tiene universidad" do
    assert build_user(role: "director", university: nil).valid?
    assert_not build_user(role: "director").valid?
  end

  test "los demás roles necesitan universidad" do
    %w[administrativo profesor ayudante alumno].each do |role|
      user = build_user(role: role, university: nil)

      assert_not user.valid?, "#{role} sin universidad debería ser inválido"
      assert user.errors.added?(:university, :blank)
    end
  end

  test "no se repite el RUT dentro de la misma universidad" do
    user = build_user(rut: users(:alumno).rut)

    assert_not user.valid?
    assert user.errors.added?(:rut, :taken, value: users(:alumno).rut)
  end

  test "el mismo RUT puede existir en la otra universidad" do
    assert_equal users(:alumno).rut, users(:alumno_iusa).rut
    assert build_user(rut: users(:profesor).rut, university: universities(:iusa), email: "otra@iusa.test").valid?
  end

  test "el correo es único en todo el sistema" do
    assert_not build_user(email: users(:alumno_iusa).email).valid?
  end

  test "rechaza roles que no existen" do
    user = build_user(role: "superadmin")

    assert_not user.valid?
    assert user.errors.added?(:role, :inclusion, value: "superadmin")
  end

  test "arma el nombre completo con nombre y apellido" do
    assert_equal "Ayudante UCV", users(:ayudante).name
  end

  test "muestra el nombre del rol en español" do
    assert_equal "Administrativo", users(:administrativo).role_name
  end

  test "el rol de la cuenta vive solo en users.role" do
    assert_not ActiveRecord::Base.connection.table_exists?(:user_roles)
    assert_nil User.reflect_on_association(:user_roles)
  end
end
