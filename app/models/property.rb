require 'open-uri'

class Property < ActiveRecord::Base
  def self.not_downloaded
    where(:downloaded_at => nil)
  end

  def self.downloaded
    where('downloaded_at is not null')
  end

  def self.not_found
    downloaded.where('raw_table is null')
  end

  def self.found
    downloaded.where('raw_table is not null')
  end

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

  def self.add_records(number=1000)
    number.times do
      property = Property.next_record
      property.save
      property.delay.download
    end
  end

  def property_id_number
    "%09d" % id_number
  end

  def detail_url
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{property_id_number}"
  end

  def table
    @table ||= Nokogiri::HTML(raw_table)
  end

  def table_element_by_id(id)
    table.css(id).first
  end

  def table_element_by_id_content(id)
    table_element_by_id(id).content.strip
  end

  def table_element_by_id_children_content(id)
    table_element_by_id(id).children.collect do |element|
      element.content.strip
    end.select(&:present?)
  end

  def owners
    table_element_by_id_content('#OwnersNameData').split(';').collect do |name|
      name.strip
    end
  end

  def owner_names
    owners.join('; ')
  end

  def reported_owner_address_lines
    table_element_by_id_children_content('#ReportedAddressData')
  end

  def reported_owner_address
    reported_owner_address_lines.join("\n")
  end

  def property_type
    table_element_by_id_content('#PropertyTypeData')
  end

  def cash_report
    table_element_by_id_content('#ctl00_ContentPlaceHolder1_CashReportData')
  end

  def reported_by
    table_element_by_id_content('#ReportedByData')
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