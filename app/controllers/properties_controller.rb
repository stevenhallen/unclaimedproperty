class PropertiesController < ApplicationController

  def show
    @property = Property.find(params[:id])
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
