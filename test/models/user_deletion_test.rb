require "test_helper"

# An account with academic history is never deleted, from any path: several of its associations cascade on
# destroy (the grades an ayudante entered, the attendance a profesor recorded, the assignments an administrativo
# made). Deactivating it keeps the history and blocks the sign in.
class UserDeletionTest < ActiveSupport::TestCase
  def account_without_history
    User.create!(first_name: "Sin", last_name: "Historial", rut: "10000001-6", email: "sin.historial@ucv.test",
                 role: "alumno", university: universities(:ucv), password: "password123")
  end

  test "una cuenta nueva no tiene historial y se elimina" do
    account = account_without_history

    assert_empty account.deletion_blockers
    assert account.destroy
  end

  test "lista todo lo que impide eliminar la cuenta" do
    assert_includes users(:alumno).deletion_blockers, "inscripciones en secciones"
    assert_includes users(:alumno).deletion_blockers, "notas como alumno"
    assert_includes users(:ayudante).deletion_blockers, "notas ingresadas"
    assert_includes users(:ayudante).deletion_blockers, "asignaciones como profesor o ayudante"
    assert_includes users(:administrativo).deletion_blockers, "asignaciones de profesores o ayudantes que realizó"
  end

  test "el historial de la otra universidad también cuenta, sin importar la universidad activa" do
    assert_includes users(:ayudante_iusa).deletion_blockers, "notas ingresadas"
  end

  test "destroy se detiene antes de borrar lo que dependía de la cuenta" do
    ayudante = users(:ayudante)

    assert_no_difference [ -> { User.count }, -> { Grade.count }, -> { SectionStaff.count } ] do
      assert_not ayudante.destroy
    end
    assert_match(/No se puede eliminar la cuenta porque tiene .*notas ingresadas/, ayudante.errors.full_messages.to_sentence)
  end

  test "solo false desactiva: las cuentas antiguas con active nulo siguen entrando" do
    account = account_without_history

    account.update_column(:active, nil)
    assert account.active_for_authentication?

    account.update_column(:active, false)
    assert account.deactivated?
    assert_not account.active_for_authentication?
    assert_equal :deactivated, account.inactive_message
  end
end
