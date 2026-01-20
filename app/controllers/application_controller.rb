class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :save_last_visited_path
  helper_method :current_user, :logged_in?, :admin_access?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def admin_access?
    return false unless current_user

    admin_email = "pjotrs.sokolovs@gmail.com"

    # In development, skip IP check for easier testing
    return current_user.email.downcase == admin_email if Rails.env.development?

    # In production, require both email and IP match
    admin_ip = "83.99.180.216"
    current_user.email.downcase == admin_email && request.remote_ip == admin_ip
  end

  def authenticate_user!
    unless logged_in?
      flash[:alert] = "Please log in to continue."
      redirect_to login_path
    end
  end

  def save_last_visited_path
    return unless request.get? && logged_in? && !request.xhr?
    return if controller_name == "sessions"

    cookies[:last_visited_path] = request.path
  end
end
