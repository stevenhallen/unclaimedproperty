require 'csv'

class Property < ActiveRecord::Base
  def self.with_id_number
    where('id_number is not null')
  end

  def self.not_downloaded
    where(:downloaded_at => nil)
  end

  def self.downloaded
    where('downloaded_at is not null')
  end

  def self.property_not_found
    downloaded.where(:property_table_html => nil)
  end

  def self.property_found
    downloaded.where('property_table_html is not null')
  end

  def self.not_found
    property_not_found
  end

  def self.found
    property_found
  end

  def self.csv_column_names
    %w(id_number owner_names reported_owner_address property_type cash_report reported_by property_url_by_id_number)
  end

  def self.write_csv(filename)
    File.open(filename, 'w') do |writer|
      writer.write(to_csv)
    end
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << csv_column_names
      property_found.find_in_batches(:batch_size => 1000) do |batches|
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

  def self.max_cash_report
    Property.found.maximum(:cash_report)
  end

  def self.max_found_id_number
    with_id_number.property_found.maximum(:id_number) || 0
  end

  def self.max_not_found_id_number_after_max_found_id_number
    max_found = max_found_id_number
    with_id_number.property_not_found.where('id_number > ?', max_found).maximum(:id_number) || max_found
  end

  def self.count_of_records_not_found_after_max_found_id_number
    max_not_found_id_number_after_max_found_id_number - max_found_id_number
  end

  def self.starting_id_number
    970000000
  end

  def self.next_id_number
    max_found_id_number.zero? ? starting_id_number : max_found_id_number + 1
  end

  def self.queue_download_for_next_batch(number=50)
    return if count_of_records_not_found_after_max_found_id_number > 10

    next_id_number.upto(next_id_number + number).each do |id_number|
      property = Property.where(:id_number => id_number).first || Property.new(:id_number => id_number)

      property.save unless property.persisted?

      property.delay.download unless property.property_table_html.present?
    end
  end

  def self.property_found_by_id_number?(id_number)
    url = "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{id_number}"

    response = response_for_url(url)

    response.present? && !response.include?('NO MATCH') && response.include?('Property_Details_Main_Page_Content_Formatting_Table')
  end

  def self.get_table(url, table_selector)
    response = Property.response_for_url(url)

    if response.nil?
      Rails.logger.warn("No response found for #{url}")
      return
    end

    if response.include?('NO MATCH')
      Rails.logger.warn("No match found for #{url}")
      return
    end

    doc = Nokogiri::HTML(response)

    doc.css(table_selector).first
  end

  def property_id_number
    "%09d" % id_number
  end

  def property_url_by_id_number
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{property_id_number}"
  end

  def property_table
    @property_table ||= Nokogiri::HTML(property_table_html)
  end

  def element_by_id(table, id)
    table.css(id).first
  end

  def element_by_id_content(table, id)
    element = element_by_id(table, id)
    element.content.strip if element.present?
  end

  def element_by_id_children_content(table, id)
    element_by_id(table, id).children.collect do |element|
      element.content.strip
    end.select(&:present?)
  end
  
  def first_name_from_owner_names
    #todo
  end

  def owners
    element_by_id_content(property_table, '#OwnersNameData').split(';').collect do |name|
      name.strip
    end
  end

  def owner_names_from_html
    owners.join('; ')
  end
  
  def city_state_zip
    owner_address_lines.split("\n").last.strip if owner_address_lines.present?
  end
  
  def postal_code_from_address_lines
    return if city_state_zip.blank?
    postal_code = city_state_zip.gsub(/\d+/).first
  end
  
  def city_state
    postal_split_string = " " + postal_code_from_address_lines
    city_state_zip.split(postal_split_string).first.strip
  end
  
  def city
    city_split_string = " " + state_from_address_lines + " "
    (city_state + " ").split(city_split_string).first.strip
  end
  
  def state_from_address_lines
    city_state.last(2)
    #TODO: Check with array of known states
  end
  
  def city_from_address_lines
    city_state_zip[0..city_state_zip.length-9].strip
  end
  
  def street_address_from_address_lines
    owner_address_lines.split("\n").first.strip if owner_address_lines.present?
  end

  def reported_owner_address_lines
    element_by_id_children_content(property_table, '#ReportedAddressData')
  end

  def reported_owner_address
    reported_owner_address_lines.join("\n")
  end

  def owner_address_lines_from_html
    reported_owner_address
  end

  def property_type_from_html
    element_by_id_content(property_table, '#PropertyTypeData')
  end

  def property_reported_from_html
    element_by_id_content(property_table, '#ctl00_ContentPlaceHolder1_PropertyReportData')
  end

  def cash_report_from_html
    begin
      from_html = element_by_id_content(property_table, '#ctl00_ContentPlaceHolder1_CashReportData')
      BigDecimal(from_html.split("\n").first.sub('$', ''))
    rescue
      Rails.logger.error("Error finding cash report for #{id}")
      BigDecimal(0)
    end
  end

  def reported_by_from_html
    element_by_id_content(property_table, '#ReportedByData')
  end

  def populate_address_fields
    %w(
      street_address
      city
      state
      postal_code
    ).each do |attribute|
      setter = "#{attribute}=".to_sym
      getter = "#{attribute}_from_address_lines".to_sym

      value = send(getter)
      if value.present?
        self.send(setter, value)
      end
    end

    save! if changed?
  end

  def populate_fields
    %w(
      cash_report
      owner_address_lines
      owner_names
      property_reported
      property_type
      reported_by
    ).each do |attribute|
      setter = "#{attribute}=".to_sym
      getter = "#{attribute}_from_html".to_sym

      value = send(getter)
      if value.present?
        self.send(setter, value)
      end
    end

    save! if changed?
  end

  def download
    Rails.logger.info("Trying to find id_number #{id_number}")

    return if property_table_html.present?

    self.downloaded_at = Time.now
    save!

    table = Property.get_table(property_url_by_id_number, '#Property_Details_Main_Page_Content_Formatting_Table')
    if table.present?
      self.property_table_html = table.to_html
      save!

      populate_fields
    end
  end
end
