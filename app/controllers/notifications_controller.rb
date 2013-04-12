class NotificationsController < ApplicationController

  def new
    @notification = Notification.new
  end

end
