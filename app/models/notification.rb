class Notification < ActiveRecord::Base
  
  validates :first_name,
              :presence => true
  validates :last_name,
              :presence => true
  validates :email,
              :presence => true,
              :uniqueness => true
              
  after_create :send_welcome

private

  def send_welcome
    NotificationMailer.welcome_email(self).deliver
  end
end
