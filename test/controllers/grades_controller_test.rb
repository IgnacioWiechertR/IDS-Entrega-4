require "test_helper"

class GradesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @grade = grades(:one)
  end

  test "should get index" do
    get grades_url
    assert_response :success
  end

  test "should get new" do
    get new_grade_url
    assert_response :success
  end

  test "should create grade" do
    assert_difference("Grade.count") do
      post grades_url, params: { grade: { entered_by_id: @grade.entered_by_id, evaluation_id: @grade.evaluation_id, feedback: @grade.feedback, rejection_comment: @grade.rejection_comment, reviewed_by_id: @grade.reviewed_by_id, score: @grade.score, status: @grade.status, student_id: @grade.student_id } }
    end

    assert_redirected_to grade_url(Grade.last)
  end

  test "should show grade" do
    get grade_url(@grade)
    assert_response :success
  end

  test "should get edit" do
    get edit_grade_url(@grade)
    assert_response :success
  end

  test "should update grade" do
    patch grade_url(@grade), params: { grade: { entered_by_id: @grade.entered_by_id, evaluation_id: @grade.evaluation_id, feedback: @grade.feedback, rejection_comment: @grade.rejection_comment, reviewed_by_id: @grade.reviewed_by_id, score: @grade.score, status: @grade.status, student_id: @grade.student_id } }
    assert_redirected_to grade_url(@grade)
  end

  test "should destroy grade" do
    assert_difference("Grade.count", -1) do
      delete grade_url(@grade)
    end

    assert_redirected_to grades_url
  end
end
