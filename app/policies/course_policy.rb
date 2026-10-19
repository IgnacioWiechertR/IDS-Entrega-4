class CoursePolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor? || user.ayudante? || user.alumno?

    # "Mis cursos": courses where the user teaches/assists a section or has an active enrollment.
    # An ayudante can also be a student in another section, so both rules apply to every role.
    can :read, Course, sections: { section_staffs: { user_id: user.id } }
    can :read, Course, sections: { enrollments: { student_id: user.id, active: true } }
  end
end
