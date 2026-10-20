require "test_helper"

# C12: the notifications are inside the portal. Each user sees only their own, newest first, and opening the
# inbox marks them as read.
class NotificationsTest < ActionDispatch::IntegrationTest
  def notify(user, message) = Notification.create!(recipient: user, kind: "prueba", message: message)

  test "la barra muestra cuántas notificaciones no leídas hay" do
    notify(users(:profesor), "3 notas de Control 1 esperan tu revisión.")
    sign_in users(:profesor)
    get courses_path

    assert_select "nav a[href=?]", notifications_path, text: /Notificaciones\s*1/
  end

  test "el buzón muestra solo las notificaciones propias, de la más nueva a la más antigua" do
    older = notify(users(:profesor), "Mensaje antiguo")
    older.update_columns(created_at: 2.days.ago)
    newer = notify(users(:profesor), "Mensaje nuevo")
    others = notify(users(:alumno), "Tu nota de Control 1 ya está publicada.")
    sign_in users(:profesor)

    get notifications_path
    assert_response :success
    assert_select "#notifications li:first-child", text: /Mensaje nuevo/
    assert_select "#notification_#{older.id}"
    assert_select "#notification_#{newer.id}.font-semibold" # unread when the page was opened
    assert_select "#notification_#{others.id}", count: 0
  end

  test "al abrir el buzón quedan leídas y el contador desaparece" do
    notification = notify(users(:profesor), "3 notas de Control 1 esperan tu revisión.")
    sign_in users(:profesor)

    get notifications_path
    assert notification.reload.read_at.present?

    get courses_path
    assert_select "nav a[href=?]", notifications_path, text: /\ANotificaciones\z/
  end

  test "sin notificaciones se muestra un mensaje" do
    Notification.where(recipient: users(:alumno)).delete_all
    sign_in users(:alumno)
    get notifications_path

    assert_select "#no-notifications", text: /No tienes notificaciones/
  end

  test "el director no tiene buzón" do
    sign_in users(:director)
    get dashboard_path
    assert_select "nav a[href=?]", notifications_path, count: 0

    get notifications_path
    assert_equal "No tienes permiso para ver esa página.", flash[:alert]
  end

  test "de punta a punta: el ayudante sube notas y el profesor ve el aviso en su buzón" do
    evaluation = Evaluation.create!(section: sections(:one), name: "Control 3", weight: 10, due_on: Date.new(2026, 11, 20))
    sign_in users(:ayudante)
    perform_enqueued_jobs do
      patch section_evaluation_grade_sheet_path(sections(:one), evaluation),
            params: { entries: { users(:alumno).id => { score: "6,0" } } }
    end
    sign_out :user

    sign_in users(:profesor)
    get notifications_path
    assert_select "#notifications", text: /1 nota de Control 3 \(ICC1001 · Sección 1\) espera tu revisión/
  end
end
