module Api
  class UserPreferencesController < ApplicationController
    def update_accordion_state
      section = params[:section]
      expanded = params[:expanded]

      if section.blank?
        render json: { error: "Section is required" }, status: :bad_request
        return
      end

      accordion_states = current_user.accordion_states || {}
      accordion_states[section] = expanded

      if current_user.update(accordion_states: accordion_states)
        render json: { success: true, accordion_states: accordion_states }
      else
        render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    end
  end
end
