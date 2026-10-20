class ReportPolicy
  include CanCan::Ability

  def initialize(user)
    return unless user
    
    # Lógica de reportes futura
  end
end