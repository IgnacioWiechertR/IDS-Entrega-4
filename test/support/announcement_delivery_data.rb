module AnnouncementDeliveryData
  def setup_announcement_delivery
    @university = universities(:ucv)
    @course = courses(:one)
    @section = sections(:one)
    @student = users(:alumno)
    @other_section = Section.create!(course: @course, term: terms(:one), number: 2)
    @other_student = announcement_student(35_100_001)
    Enrollment.create!(section: @other_section, student: @other_student)
    @inactive_student = announcement_student(35_100_002)
    Enrollment.create!(section: @section, student: @inactive_student, active: false)
    @unrelated_section = Section.create!(course: courses(:three), term: terms(:one), number: 1)
    @unrelated_student = announcement_student(35_100_003)
    Enrollment.create!(section: @unrelated_section, student: @unrelated_student)

    @section_announcement = announcements(:one)
    @general_announcement = announcement_record(subject: "Aviso general")
    @other_announcement = announcement_record(section: @other_section, subject: "Solo segunda sección")
    @unrelated_announcement = announcement_record(course: courses(:three), section: @unrelated_section, subject: "Otro curso")
  end

  def announcement_student(number, role: "alumno")
    User.create!(first_name: "Estudiante", last_name: number.to_s, rut: Rut.build(number),
      email: "anuncios.#{number}@ucv.test", role: role, university: universities(:ucv), password: "password123")
  end

  def announcement_record(course: @course, section: nil, subject:, body: "Mensaje para sus destinatarios")
    Announcement.create!(course: course, section: section, author: users(:profesor), subject: subject, body: body)
  end

  def in_ucv(&)
    ActsAsTenant.with_tenant(universities(:ucv), &)
  end
end
