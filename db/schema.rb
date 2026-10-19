# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_19_215312) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "section_id"
    t.string "subject"
    t.text "body"
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_announcements_on_author_id"
    t.index ["course_id"], name: "index_announcements_on_course_id"
    t.index ["section_id"], name: "index_announcements_on_section_id"
  end

  create_table "attendance_records", force: :cascade do |t|
    t.bigint "attendance_session_id", null: false
    t.bigint "student_id", null: false
    t.string "status", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.index ["attendance_session_id", "student_id"], name: "index_attendance_records_on_session_and_student", unique: true
    t.index ["attendance_session_id"], name: "index_attendance_records_on_attendance_session_id"
    t.index ["student_id"], name: "index_attendance_records_on_student_id"
    t.index ["university_id"], name: "index_attendance_records_on_university_id"
  end

  create_table "attendance_sessions", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.date "held_on", null: false
    t.bigint "recorded_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.index ["recorded_by_id"], name: "index_attendance_sessions_on_recorded_by_id"
    t.index ["section_id", "held_on"], name: "index_attendance_sessions_on_section_id_and_held_on", unique: true
    t.index ["section_id"], name: "index_attendance_sessions_on_section_id"
    t.index ["university_id"], name: "index_attendance_sessions_on_university_id"
  end

  create_table "course_coordinators", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.bigint "term_id", null: false
    t.bigint "user_id", null: false
    t.bigint "assigned_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.index ["assigned_by_id"], name: "index_course_coordinators_on_assigned_by_id"
    t.index ["course_id", "term_id"], name: "index_course_coordinators_on_course_id_and_term_id", unique: true
    t.index ["course_id"], name: "index_course_coordinators_on_course_id"
    t.index ["term_id"], name: "index_course_coordinators_on_term_id"
    t.index ["university_id"], name: "index_course_coordinators_on_university_id"
    t.index ["user_id"], name: "index_course_coordinators_on_user_id"
  end

  create_table "courses", force: :cascade do |t|
    t.bigint "university_id", null: false
    t.bigint "faculty_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["faculty_id"], name: "index_courses_on_faculty_id"
    t.index ["university_id", "code"], name: "index_courses_on_university_id_and_code", unique: true
    t.index ["university_id"], name: "index_courses_on_university_id"
  end

  create_table "enrollments", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.bigint "student_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.index ["section_id", "student_id"], name: "index_enrollments_on_section_id_and_student_id", unique: true
    t.index ["section_id"], name: "index_enrollments_on_section_id"
    t.index ["student_id"], name: "index_enrollments_on_student_id"
    t.index ["university_id"], name: "index_enrollments_on_university_id"
  end

  create_table "evaluations", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.string "name", null: false
    t.decimal "weight", precision: 5, scale: 2, null: false
    t.date "due_on"
    t.text "rubric"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.index ["section_id"], name: "index_evaluations_on_section_id"
    t.index ["university_id"], name: "index_evaluations_on_university_id"
  end

  create_table "faculties", force: :cascade do |t|
    t.bigint "university_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["university_id"], name: "index_faculties_on_university_id"
  end

  create_table "grades", force: :cascade do |t|
    t.bigint "evaluation_id", null: false
    t.bigint "student_id", null: false
    t.decimal "score", precision: 2, scale: 1, null: false
    t.string "status", default: "pendiente", null: false
    t.text "feedback"
    t.text "rejection_comment"
    t.bigint "entered_by_id", null: false
    t.bigint "reviewed_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.decimal "points", precision: 6, scale: 2
    t.index ["entered_by_id"], name: "index_grades_on_entered_by_id"
    t.index ["evaluation_id", "student_id"], name: "index_grades_on_evaluation_id_and_student_id", unique: true
    t.index ["evaluation_id"], name: "index_grades_on_evaluation_id"
    t.index ["reviewed_by_id"], name: "index_grades_on_reviewed_by_id"
    t.index ["student_id"], name: "index_grades_on_student_id"
    t.index ["university_id"], name: "index_grades_on_university_id"
  end

  create_table "materials", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_materials_on_course_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "recipient_id", null: false
    t.string "kind", null: false
    t.string "message", null: false
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
    t.index ["university_id"], name: "index_notifications_on_university_id"
  end

  create_table "section_staffs", force: :cascade do |t|
    t.bigint "section_id", null: false
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.bigint "assigned_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "university_id", null: false
    t.index ["assigned_by_id"], name: "index_section_staffs_on_assigned_by_id"
    t.index ["section_id", "user_id"], name: "index_section_staffs_on_section_id_and_user_id", unique: true
    t.index ["section_id"], name: "index_section_staffs_on_section_id"
    t.index ["university_id"], name: "index_section_staffs_on_university_id"
    t.index ["user_id"], name: "index_section_staffs_on_user_id"
  end

  create_table "sections", force: :cascade do |t|
    t.bigint "university_id", null: false
    t.bigint "course_id", null: false
    t.bigint "term_id", null: false
    t.integer "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "term_id", "number"], name: "index_sections_on_course_id_and_term_id_and_number", unique: true
    t.index ["course_id"], name: "index_sections_on_course_id"
    t.index ["term_id"], name: "index_sections_on_term_id"
    t.index ["university_id"], name: "index_sections_on_university_id"
  end

  create_table "terms", force: :cascade do |t|
    t.bigint "university_id", null: false
    t.string "name", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.boolean "current", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["university_id"], name: "index_terms_on_university_id"
    t.index ["university_id"], name: "index_terms_on_university_id_current", unique: true, where: "current"
  end

  create_table "universities", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_universities_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.bigint "university_id"
    t.string "email", default: "", null: false
    t.string "rut"
    t.string "first_name"
    t.string "last_name"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "alumno", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["university_id", "rut"], name: "index_users_on_university_id_and_rut", unique: true
    t.index ["university_id"], name: "index_users_on_university_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "announcements", "courses"
  add_foreign_key "announcements", "sections"
  add_foreign_key "announcements", "users", column: "author_id"
  add_foreign_key "attendance_records", "attendance_sessions"
  add_foreign_key "attendance_records", "universities"
  add_foreign_key "attendance_records", "users", column: "student_id"
  add_foreign_key "attendance_sessions", "sections"
  add_foreign_key "attendance_sessions", "universities"
  add_foreign_key "attendance_sessions", "users", column: "recorded_by_id"
  add_foreign_key "course_coordinators", "courses"
  add_foreign_key "course_coordinators", "terms"
  add_foreign_key "course_coordinators", "universities"
  add_foreign_key "course_coordinators", "users"
  add_foreign_key "course_coordinators", "users", column: "assigned_by_id"
  add_foreign_key "courses", "faculties"
  add_foreign_key "courses", "universities"
  add_foreign_key "enrollments", "sections"
  add_foreign_key "enrollments", "universities"
  add_foreign_key "enrollments", "users", column: "student_id"
  add_foreign_key "evaluations", "sections"
  add_foreign_key "evaluations", "universities"
  add_foreign_key "faculties", "universities"
  add_foreign_key "grades", "evaluations"
  add_foreign_key "grades", "universities"
  add_foreign_key "grades", "users", column: "entered_by_id"
  add_foreign_key "grades", "users", column: "reviewed_by_id"
  add_foreign_key "grades", "users", column: "student_id"
  add_foreign_key "materials", "courses"
  add_foreign_key "notifications", "universities"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "section_staffs", "sections"
  add_foreign_key "section_staffs", "universities"
  add_foreign_key "section_staffs", "users"
  add_foreign_key "section_staffs", "users", column: "assigned_by_id"
  add_foreign_key "sections", "courses"
  add_foreign_key "sections", "terms"
  add_foreign_key "sections", "universities"
  add_foreign_key "terms", "universities"
  add_foreign_key "users", "universities"
end
