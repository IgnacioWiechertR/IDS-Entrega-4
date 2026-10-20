# Composes the policies named in the C4 model. Each card adds the rules it needs.
class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user

    [ AccountPolicy, CoursePolicy, ReportPolicy, TeacherAssignmentPolicy ].each { |policy| merge policy.new(user) }
  end
end
