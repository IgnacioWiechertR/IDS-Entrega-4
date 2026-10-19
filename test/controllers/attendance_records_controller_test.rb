require "test_helper"

class AttendanceRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @attendance_record = attendance_records(:one)
  end

  test "should get index" do
    get attendance_records_url
    assert_response :success
  end

  test "should get new" do
    get new_attendance_record_url
    assert_response :success
  end

  test "should create attendance_record" do
    assert_difference("AttendanceRecord.count") do
      post attendance_records_url, params: { attendance_record: { attendance_session_id: @attendance_record.attendance_session_id, status: @attendance_record.status, student_id: @attendance_record.student_id } }
    end

    assert_redirected_to attendance_record_url(AttendanceRecord.last)
  end

  test "should show attendance_record" do
    get attendance_record_url(@attendance_record)
    assert_response :success
  end

  test "should get edit" do
    get edit_attendance_record_url(@attendance_record)
    assert_response :success
  end

  test "should update attendance_record" do
    patch attendance_record_url(@attendance_record), params: { attendance_record: { attendance_session_id: @attendance_record.attendance_session_id, status: @attendance_record.status, student_id: @attendance_record.student_id } }
    assert_redirected_to attendance_record_url(@attendance_record)
  end

  test "should destroy attendance_record" do
    assert_difference("AttendanceRecord.count", -1) do
      delete attendance_record_url(@attendance_record)
    end

    assert_redirected_to attendance_records_url
  end
end
