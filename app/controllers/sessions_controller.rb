class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create ]

  def new
    redirect_to dashboards_ryanair_path if logged_in?
  end

  def create
    user = User.find_by("LOWER(email) = ?", params[:email].to_s.downcase.strip)

    if user
      session[:user_id] = user.id
      redirect_to dashboards_ryanair_path, notice: "Welcome back!"
    else
      flash.now[:alert] = "User not found. Please contact administrator."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to login_path, notice: "You have been logged out."
  end
end
