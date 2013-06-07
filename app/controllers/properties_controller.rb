class PropertiesController < ApplicationController
  def lookup_name
    last_name = params[:name]
    redirect_to root_path and return if last_name.blank?
    redirect_to name_search_properties_path(last_name)
  end

  def show
    @property = Property.find(params[:id])
    @notification = Notification.new(:last_name => @property.last_name, :first_name => @property.first_name)
  end
  
  def name_search
    @properties = Property.where('last_name ilike ?', params[:name])
    render :index
  end
  
  def zip_search
    @properties = Property.where('postal_code like ?', "#{params[:zip]}%")
    render :index
  end

end
