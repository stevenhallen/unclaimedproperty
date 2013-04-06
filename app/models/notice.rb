require 'csv'
require 'people_places_things'

include PeoplePlacesThings

class Notice < ActiveRecord::Base
  def self.without_id_number
    where(:id_number => nil)
  end

  def self.with_id_number
    where('id_number is not null')
  end

  def self.not_downloaded
    where(:downloaded_at => nil)
  end

  def self.downloaded
    where('downloaded_at is not null')
  end

  def self.not_found
    downloaded.where(:notice_table_html => nil)
  end

  def self.found
    downloaded.where('notice_table_html is not null')
  end

  def self.max_found_rec_id
    found.maximum(:rec_id)
  end

  def self.count_of_records_not_found_after_max_found_rec_id
    not_found.where('rec_id > ?', max_found_rec_id).count
  end

  def self.starting_rec_id
    1
  end

  def self.next_rec_id
    max_found = max_found_rec_id

    max_found.nil? ? starting_rec_id : max_found + 1
  end

  def self.retry_not_found
    Notice.not_found.find_in_batches(:batch_size => 1000) do |notices|
      notices.each do |notice|
        notice.delay.download
      end
    end
  end

  def self.queue_download_for_next_batch(number=50)
    return if count_of_records_not_found_after_max_found_rec_id > 10

    next_rec_id.upto(next_rec_id + number).each do |rec_id|
      record = where(:rec_id => rec_id).first || new(:rec_id => rec_id)

      record.save unless record.persisted?

      record.delay.download unless record.notice_table_html.present?
    end
  end

  def notice_url
    "http://scoweb.sco.ca.gov/UCP/NoticeDetails.aspx?propertyRecID=#{rec_id}"
  end

  def property_url
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyRecID=#{rec_id}"
  end

  def notice_table
    @notice_table ||= Nokogiri::HTML(notice_table_html)
  end

  def html_table
    notice_table
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
      from_html = UrlUtils.element_by_id_content(html_table, '#AmountData')
      BigDecimal(from_html.split("\n").first.sub('$', ''))
    rescue
      Rails.logger.error("Error finding cash report for #{id}")
      BigDecimal(0)
    end
  end

  def reported_on_from_html
    begin
      Chronic.parse(UrlUtils.element_by_id_content(html_table, '#DateReportedData')).to_date
    rescue
      Rails.logger.error("Error finding reported on for #{id}")
      nil
    end
  end

  def reported_by_from_html
    UrlUtils.element_by_id_content(html_table, '#ReportedByData')
  end

  def property_table
    @property_table ||= UrlUtils.get_table(property_url, '#Property_Details_Main_Page_Content_Formatting_Table')
  end

  def id_number_from_html
    return nil unless property_table.present?

    lines = UrlUtils.element_by_id_content(property_table, '#tbl_HeaderInformation') || ''

    lines = lines.split("\n").collect(&:strip).select(&:present?)

    return nil unless lines.present?

    index = lines.index { |line| line.starts_with? 'Property ID Number:' }

    lines[index + 1].to_i
  end

  # TODO:
  # - Business Contact Information (holder name and address)
  # - Shares Reported
  # - Name of Security Reported
  # - Date of Last Contact

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
      id_number
      reported_on
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
    Rails.logger.info("Trying to find rec_id #{rec_id}")

    return if notice_table_html.present?

    self.downloaded_at = Time.now
    save!

    table = UrlUtils.get_table(notice_url, '#Notice_Details_Main_Page_Content_Formatting_Table')
    if table.present?
      self.notice_table_html = table.to_html
      save!

      populate_fields
    end
  end
end
