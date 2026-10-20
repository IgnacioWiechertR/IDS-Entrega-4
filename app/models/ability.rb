class Ability
  include CanCan::Ability

  def initialize(user)
    return unless user
    
    # Todos los usuarios logueados pueden ver el dashboard
    can :read, :dashboard

    [ AccountPolicy, CoursePolicy, ReportPolicy, SectionPolicy ].each { |policy| merge policy.new(user) }
  end
end