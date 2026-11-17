class MaterialPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor? && user.university_id.present?

    # B1: a profesor uploads to courses they teach or coordinate, within their university.
    can :create, Material, course: {
      university_id: user.university_id,
      sections: { section_staffs: { user_id: user.id, role: "profesor" } }
    }
    can :create, Material, course: {
      university_id: user.university_id,
      course_coordinators: { user_id: user.id }
    }
  end
end
