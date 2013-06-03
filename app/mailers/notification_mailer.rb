class NotificationMailer < ActionMailer::Base
  default from: "unclaimed@stevenhallen.com"
  
  def welcome_email(notification)
    @notification = notification
    mail(:to => notification.email, :subject => "Welcome to Unclaimed Notifier")
  end
end
