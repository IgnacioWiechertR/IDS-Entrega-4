require "test_helper"

class AttendanceSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @attendance_session = attendance_sessions(:one)
  end

  test "should get index" do
    get attendance_sessions_url
    assert_response :success
  end

  test "should get new" do
    get new_attendance_session_url
    assert_response :success
  end

  test "should create attendance_session" do
    assert_difference("AttendanceSession.count") do
      post attendance_sessions_url, params: { attendance_session: { held_on: @attendance_session.held_on, recorded_by_id: @attendance_session.recorded_by_id, section_id: @attendance_session.section_id } }
    end

    assert_redirected_to attendance_session_url(AttendanceSession.last)
  end

  test "should show attendance_session" do
    get attendance_session_url(@attendance_session)
    assert_response :success
  end

  test "should get edit" do
    get edit_attendance_session_url(@attendance_session)
    assert_response :success
  end

  test "should update attendance_session" do
    patch attendance_session_url(@attendance_session), params: { attendance_session: { held_on: @attendance_session.held_on, recorded_by_id: @attendance_session.recorded_by_id, section_id: @attendance_session.section_id } }
    assert_redirected_to attendance_session_url(@attendance_session)
  end

  test "should destroy attendance_session" do
    assert_difference("AttendanceSession.count", -1) do
      delete attendance_session_url(@attendance_session)
    end

    assert_redirected_to attendance_sessions_url
  end
end
