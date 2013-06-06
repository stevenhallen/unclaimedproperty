class WelcomeController < ApplicationController
  def index
    @properties = Property.most_recent(20).where('cash_report > 10')
    @notification = Notification.new
  end

  def about
    @notification = Notification.new
  end
end