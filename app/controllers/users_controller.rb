class UsersController < ApplicationController
  before_action :require_admin_access

  def index
    @users = User.all.order(:email).includes(
      :ryanair_flight_searches,
      :airbaltic_flight_searches,
      :norwegian_flight_searches,
      :bode_flight_searches,
      :flydubai_flight_searches,
      :turkish_flight_searches,
      :booking_searches,
      :ss_flat_follows,
      :ss_house_follows
    )
  end

  def create
    @user = User.new(user_params)

    if @user.save
      UserMailer.welcome_email(@user).deliver_later
      redirect_to users_path, notice: "User #{@user.email} created successfully."
    else
      redirect_to users_path, alert: @user.errors.full_messages.join(", ")
    end
  end

  def destroy
    @user = User.find(params[:id])

    if @user.email.downcase == "pjotrs.sokolovs@gmail.com"
      redirect_to users_path, alert: "Cannot delete the admin user."
      return
    end

    @user.destroy
    redirect_to users_path, notice: "User #{@user.email} deleted successfully."
  end

  private

  def require_admin_access
    redirect_to root_path unless admin_access?
  end

  def user_params
    params.require(:user).permit(:email)
  end
end
