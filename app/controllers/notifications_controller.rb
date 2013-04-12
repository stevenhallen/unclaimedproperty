class NotificationsController < ApplicationController

  def new
    @notification = Notification.new
  end

  def create
    @notification = Notification.new(notification_params)

    if @notification.save
      redirect_to root_path, :notice => 'Saved'
    else
      redirect_to root_path, :alert => 'Not saved'
    end
  end

  private

  def notification_params
    params.require(:notification).permit(:first_name, :middle_name, :last_name, :email)
  end
end
