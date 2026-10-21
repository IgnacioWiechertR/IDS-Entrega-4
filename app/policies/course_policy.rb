class CoursePolicy
  include CanCan::Ability

  def initialize(user)
    # The director only reads, in the university picked with the selector. Course is scoped to the active
    # university (A3), so the rule needs no condition and never reaches the other university.
    can :read, Course if user.director?

    return unless user.profesor? || user.ayudante? || user.alumno? || user.administrativo?

    can :manage, Course, university_id: user.university_id if user.administrativo?

    can :read, Course, sections: { section_staffs: { user_id: user.id } }
    can :read, Course, sections: { enrollments: { student_id: user.id, active: true } }

    # A coordinator sees every course they coordinate, even without teaching one of its sections. They do not
    # edit or delete it: that stays with the administrativo (A13, A14).
    can :read, Course, course_coordinators: { user_id: user.id } if user.profesor?
  end
end
