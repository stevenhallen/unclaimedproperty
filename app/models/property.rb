require 'csv'
require 'people_places_things'

include PeoplePlacesThings

class Property < ActiveRecord::Base
  def self.not_downloaded
    where(:downloaded_at => nil)
  end

  def self.downloaded
    where('downloaded_at is not null')
  end

  def self.not_found
    downloaded.where(:property_table_html => nil)
  end

  def self.found
    downloaded.where('property_table_html is not null')
  end

  def self.csv_column_names
    %w(id_number owner_names reported_owner_address property_type cash_report reported_by property_url)
  end

  def self.write_csv(filename)
    File.open(filename, 'w') do |writer|
      writer.write(to_csv)
    end
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

  def self.max_cash_report
    found.maximum(:cash_report)
  end

  def self.max_found_id_number
    found.maximum(:id_number) || 0
  end

  def self.count_of_records_not_found_after_max_found_id_number
    not_found.where('id_number > ?', max_found_id_number).count
  end

  def self.starting_id_number
    970000000
  end

  def self.next_id_number
    max_found = max_found_id_number

    max_found.nil? ? starting_id_number : max_found + 1
  end

  def self.queue_download_for_next_batch(number=50)
    return if count_of_records_not_found_after_max_found_id_number > 10

    next_id_number.upto(next_id_number + number).each do |id_number|
      record = where(:id_number => id_number).first || new(:id_number => id_number)

      record.save unless record.persisted?

      record.delay.download unless property.property_table_html.present?
    end
  end

  def self.found_by_id_number?(id_number)
    url = "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{id_number}"

    response = UrlUtils.response_for_url(url)

    response.present? && !response.include?('NO MATCH') && response.include?('Property_Details_Main_Page_Content_Formatting_Table')
  end

  def property_id_number
    "%09d" % id_number
  end

  def property_url
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{property_id_number}"
  end

  def property_table
    @property_table ||= Nokogiri::HTML(property_table_html)
  end

  def html_table
    property_table
  end

  def owners
    UrlUtils.element_by_id_content(html_table, '#OwnersNameData').split(';').collect do |name|
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

  def city_from_address_lines
    city_split_string = " " + state_from_address_lines + " "
    (city_state + " ").split(city_split_string).first.strip
  end

  def state_from_address_lines
    city_state.last(2)
    #TODO: Check with array of known states
  end

  def street_address_from_address_lines
    owner_address_lines.split("\n").first.strip if owner_address_lines.present?
  end

  def reported_owner_address_lines
    UrlUtils.element_by_id_children_content(html_table, '#ReportedAddressData')
  end

  def reported_owner_address
    reported_owner_address_lines.join("\n")
  end

  def owner_address_lines_from_html
    reported_owner_address
  end

  def property_type_from_html
    UrlUtils.element_by_id_content(html_table, '#PropertyTypeData')
  end

  def property_reported_from_html
    UrlUtils.element_by_id_content(html_table, '#ctl00_ContentPlaceHolder1_PropertyReportData')
  end

  def cash_report_from_html
    begin
      from_html = UrlUtils.element_by_id_content(html_table, '#ctl00_ContentPlaceHolder1_CashReportData')
      BigDecimal(from_html.split("\n").first.sub('$', ''))
    rescue
      Rails.logger.error("Error finding cash report for #{id}")
      BigDecimal(0)
    end
  end

  def reported_by_from_html
    UrlUtils.element_by_id_content(html_table, '#ReportedByData')
  end

  def populate_name_fields
    name = PersonName.new(owner_names.split("; ").first, :last_first_middle)
    self.first_name = name.first
    self.middle_name = name.middle
    self.last_name = name.last
    save! if changed?
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

    table = UrlUtils.get_table(property_url, '#Property_Details_Main_Page_Content_Formatting_Table')
    if table.present?
      self.property_table_html = table.to_html
      save!

      populate_fields
    end
  end
end
