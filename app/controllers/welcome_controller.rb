class WelcomeController < ApplicationController
  def index
    @properties = Property.most_recent
  end
end