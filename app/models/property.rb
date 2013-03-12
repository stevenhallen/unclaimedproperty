require 'csv'

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

  def self.csv_column_names
    %w(property_id_number owner_names reported_owner_address property_type cash_report reported_by detail_url)
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << csv_column_names
      found.find_in_batches(:batch_size => 1000) do |batches|
        batches.each do |property|
          csv << csv_column_names.collect { |name| property.send(name.to_sym) }
        end
      end
    end
  end

  def self.response_for_url(url, options = {})
    timeout = options.fetch(:timeout, 15)

    response = nil

    begin
      Timeout::timeout(timeout) do
        Rails.logger.info("Fetching #{url}")

        response = HTTParty.get(url)
      end
    rescue Timeout::Error
      Rails.logger.warn("Timed out getting #{url}")
    end

    response
  end

  def download
    Rails.logger.info("Trying to find property ID number #{property_id_number}")

    self.downloaded_at = Time.now
    self.save!

    response = Property.response_for_url(detail_url)

    if response.nil?
      Rails.logger.warn("No response found for property ID number #{property_id_number}")
      return
    end

    if response.include?('NO MATCH')
      Rails.logger.warn("No match found for property ID number #{property_id_number}")
      return
    end

    doc = Nokogiri::HTML(response)

    table = doc.css('#Property_Details_Main_Page_Content_Formatting_Table').first

    if table.present?
      self.raw_table = table.to_html
      self.save!
    else
      Rails.logger.warn("No details table found for #{property_id_number}")
    end
  end
end