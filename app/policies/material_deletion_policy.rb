class MaterialDeletionPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user.profesor? && user.university_id.present?

    can :index, :material_deletions
    can :destroy, Material, uploaded_by_id: user.id, course: {
      university_id: user.university_id,
      sections: { section_staffs: { user_id: user.id, role: "profesor" } }
    }
    can :destroy, Material, uploaded_by_id: user.id, course: {
      university_id: user.university_id,
      course_coordinators: { user_id: user.id }
    }
  end
end
