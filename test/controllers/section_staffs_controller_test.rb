require "test_helper"

class SectionStaffsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @section_staff = section_staffs(:one)
  end

  test "should get index" do
    get section_staffs_url
    assert_response :success
  end

  test "should get new" do
    get new_section_staff_url
    assert_response :success
  end

  test "should create section_staff" do
    assert_difference("SectionStaff.count") do
      post section_staffs_url, params: { section_staff: { assigned_by_id: @section_staff.assigned_by_id, role: @section_staff.role, section_id: @section_staff.section_id, user_id: @section_staff.user_id } }
    end

    assert_redirected_to section_staff_url(SectionStaff.last)
  end

  test "should show section_staff" do
    get section_staff_url(@section_staff)
    assert_response :success
  end

  test "should get edit" do
    get edit_section_staff_url(@section_staff)
    assert_response :success
  end

  test "should update section_staff" do
    patch section_staff_url(@section_staff), params: { section_staff: { assigned_by_id: @section_staff.assigned_by_id, role: @section_staff.role, section_id: @section_staff.section_id, user_id: @section_staff.user_id } }
    assert_redirected_to section_staff_url(@section_staff)
  end

  test "should destroy section_staff" do
    assert_difference("SectionStaff.count", -1) do
      delete section_staff_url(@section_staff)
    end

    assert_redirected_to section_staffs_url
  end
end
