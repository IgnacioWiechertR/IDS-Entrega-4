class CoursePolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor? || user.ayudante? || user.alumno? || user.administrativo?

    can :manage, Course, university_id: user.university_id if user.administrativo?

    can :read, Course, sections: { section_staffs: { user_id: user.id } }
    can :read, Course, sections: { enrollments: { student_id: user.id, active: true } }
  end
end
