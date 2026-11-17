module DashboardHelper
  # Approval and failure rates (D1) are only final once the grade records of the period are closed.
  def summary_rate(summary, rate)
    if !summary.records_closed?
      "Actas abiertas"
    elsif rate
      number_to_percentage(rate, precision: 0)
    else
      "—"
    end
  end
end
