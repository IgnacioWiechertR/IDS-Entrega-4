class SectionPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor? || user.ayudante? || user.administrativo? || user.alumno?

    # El administrativo gestiona todas las secciones de su universidad
    can :manage, Section, university_id: user.university_id if user.administrativo?

    # El coordinador puede crear/editar/eliminar secciones de sus cursos asignados
    can %i[create update destroy], Section, course: { course_coordinators: { user_id: user.id } }

    # Profesores y ayudantes pueden leer las secciones donde están asignados
    can :read, Section, section_staffs: { user_id: user.id }

    # Alumnos pueden leer las secciones donde están inscritos activos
    can :read, Section, enrollments: { student_id: user.id, active: true }
  end
end
