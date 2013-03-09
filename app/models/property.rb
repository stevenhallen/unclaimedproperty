require 'open-uri'

class Property < ActiveRecord::Base
  scope :need_to_download, where(:downloaded_at => nil)

  def self.random_id_number
    "%09d" % rand(1..999999999)
  end

  def self.last_id_number
    order('id_number DESC').limit(1).pluck(:id_number).last
  end

  def self.next_id_number
    (last_id_number || 0) + 1
  end

  def self.next_record
    Property.new(:id_number => next_id_number)
  end

  def property_id_number
    "%09d" % id_number
  end

  def detail_url
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{property_id_number}"
  end

  def download
    Rails.logger.info("Trying to find property ID number #{property_id_number}")

    self.downloaded_at = Time.now
    self.save!

    begin
      Timeout::timeout(10) do
        doc = Nokogiri::HTML(open(detail_url))

        table = doc.css('#Property_Details_Main_Page_Content_Formatting_Table').first

        if table.present?
          self.raw_table = table.to_html
          self.save!
        end
      end
    rescue Timeout::Error
      Rails.logger.warn("Timed out trying to find property ID number #{property_id_number}")
    end
  end
end