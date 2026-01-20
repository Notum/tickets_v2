module ApplicationHelper
  def alert_class_for(type)
    case type.to_s
    when "success", "notice"
      "alert-success"
    when "error", "alert"
      "alert-error"
    when "warning"
      "alert-warning"
    when "info"
      "alert-info"
    else
      "alert-info"
    end
  end
end
