class CoursePolicy
  include CanCan::Ability

  def initialize(user)
    # El administrativo administra los cursos de su propia universidad
    if user.administrativo?
      can :manage, Course, university_id: user.university_id
    end

    # "Mis cursos": los demás roles ven solo donde enseñan o están inscritos
    if user.profesor? || user.ayudante? || user.alumno?
      can :read, Course, sections: { section_staffs: { user_id: user.id } }
      can :read, Course, sections: { enrollments: { student_id: user.id, active: true } }
    end
  end
end