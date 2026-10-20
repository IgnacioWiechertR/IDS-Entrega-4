class SectionPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor? || user.ayudante? || user.administrativo? || user.alumno?

    can :manage, Section, university_id: user.university_id if user.administrativo?

    can [ :read, :create, :update, :destroy ], Section, course: { course_coordinators: { user_id: user.id } }

    can :read, Section, section_staffs: { user_id: user.id }

    can :read, Section, enrollments: { student_id: user.id, active: true }
  end
end
