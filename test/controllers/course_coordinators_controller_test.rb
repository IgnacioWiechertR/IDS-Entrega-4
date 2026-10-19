require "test_helper"

class CourseCoordinatorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @course_coordinator = course_coordinators(:one)
  end

  test "should get index" do
    get course_coordinators_url
    assert_response :success
  end

  test "should get new" do
    get new_course_coordinator_url
    assert_response :success
  end

  test "should create course_coordinator" do
    assert_difference("CourseCoordinator.count") do
      post course_coordinators_url, params: { course_coordinator: { assigned_by_id: @course_coordinator.assigned_by_id, course_id: @course_coordinator.course_id, term_id: @course_coordinator.term_id, user_id: @course_coordinator.user_id } }
    end

    assert_redirected_to course_coordinator_url(CourseCoordinator.last)
  end

  test "should show course_coordinator" do
    get course_coordinator_url(@course_coordinator)
    assert_response :success
  end

  test "should get edit" do
    get edit_course_coordinator_url(@course_coordinator)
    assert_response :success
  end

  test "should update course_coordinator" do
    patch course_coordinator_url(@course_coordinator), params: { course_coordinator: { assigned_by_id: @course_coordinator.assigned_by_id, course_id: @course_coordinator.course_id, term_id: @course_coordinator.term_id, user_id: @course_coordinator.user_id } }
    assert_redirected_to course_coordinator_url(@course_coordinator)
  end

  test "should destroy course_coordinator" do
    assert_difference("CourseCoordinator.count", -1) do
      delete course_coordinator_url(@course_coordinator)
    end

    assert_redirected_to course_coordinators_url
  end
end
