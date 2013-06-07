class WelcomeController < ApplicationController
  def index
    limit = Rails.env == "production" ? 200 : 10
    @properties = Property.most_recent(20).where("cash_report > #{limit}")
    @notification = Notification.new
  end

  def about
    @notification = Notification.new
  end
end