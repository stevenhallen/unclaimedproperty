require 'open-uri'

class Property < ActiveRecord::Base
  def self.need_to_download
    where(:downloaded_at => nil)
  end

  def self.downloaded
    where('downloaded_at is not null')
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

  def property_id_number
    "%09d" % id_number
  end

  def detail_url
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{property_id_number}"
  end

  def table
    @table ||= Nokogiri::HTML(raw_table)
  end

  def owners_names
    table.css('#OwnersNameData').first.content.strip.split(';').map { |name| name.strip }.join('; ')
  end

  def reported_owner_address
    table.css('#ReportedAddressData').first.children.collect { |el| el.content.strip }.select(&:present?).join("\n")
  end

  def property_type
    table.css('#PropertyTypeData').first.content.strip
  end

  def cash_report
    table.css('#ctl00_ContentPlaceHolder1_CashReportData').first.content.strip
  end

  def reported_by
    table.css('#ReportedByData').first.content.strip
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