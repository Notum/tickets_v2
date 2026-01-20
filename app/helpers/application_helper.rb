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

  def accordion_expanded?(section)
    return true unless current_user

    states = current_user.accordion_states || {}
    # Default to true (expanded) if not set
    states.fetch(section.to_s, true)
  end
end
