require 'csv'

class Property < ActiveRecord::Base
  def self.with_id_number
    where('id_number is not null')
  end

  def self.with_rec_id
    where('rec_id is not null')
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

  def self.notice_not_found
    downloaded.where(:notice_table_html => nil)
  end

  def self.notice_found
    downloaded.where('notice_table_html is not null')
  end

  def self.found
    notice_found.property_found
  end

  def self.not_found
    notice_not_found.property_not_found
  end

  def self.random_id_number
    "%09d" % rand(1..999999999)
  end

  def self.random_rec_id
    rand(1..found.last_rec_id)
  end

  def self.last_id_number
    with_id_number.order('id_number DESC').limit(1).pluck(:id_number).last
  end

  def self.last_rec_id
    with_rec_id.order('rec_id DESC').limit(1).pluck(:rec_id).last
  end

  def self.next_id_number
    (last_id_number || 0) + 1
  end

  def self.next_rec_id
    (last_rec_id || 0) + 1
  end

  def self.next_record_by_id_number
    Property.new(:id_number => next_id_number)
  end

  def self.next_record_by_rec_id
    Property.new(:rec_id => next_rec_id)
  end

  def self.add_records(number=1000, by='rec_id')
    number.times do
      property = Property.send("next_record_by_#{by}")
      property.save
      property.delay.download
    end
  end

  def property_id_number
    "%09d" % id_number
  end

  def notice_url_by_id_number
    "http://scoweb.sco.ca.gov/UCP/NoticeDetails.aspx?propertyID=#{property_id_number}"
  end

  def notice_url_by_rec_id
    "http://scoweb.sco.ca.gov/UCP/NoticeDetails.aspx?propertyRecID=#{rec_id}"
  end

  def property_url_by_id_number
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyID=#{property_id_number}"
  end

  def property_url_by_rec_id
    "http://scoweb.sco.ca.gov/UCP/PropertyDetails.aspx?propertyRecID=#{rec_id}"
  end

  def property_table
    @property_table ||= Nokogiri::HTML(property_table_html)
  end

  def notice_table
    @notice_table ||= Nokogiri::HTML(notice_table_html)
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

  # TODO:
  # 1.  Define two separate mappings:
  #
  #     a.  From the notice table (all records have a notice record)
  #     b.  From the property table (only held records have a property record)
  #
  # 2.  Calculate a digest for the fields that are expected to be immutable
  # 3.  Compare them
  def id_number_from_html
    element = element_by_id_content(property_table, '#tbl_HeaderInformation')
    lines = element.split("\n")
    lines = lines.collect(&:strip).select(&:present?)

    header, header_index = lines.each_with_index.select { |item, index| item.starts_with? 'Property ID Number:' }.first

    lines[header_index + 1].to_i
  end

  def owners
    element_by_id_content(property_table, '#OwnersNameData').split(';').collect do |name|
      name.strip
    end
  end

  def owner_names
    owners.join('; ')
  end

  def reported_owner_address_lines
    element_by_id_children_content(property_table, '#ReportedAddressData')
  end

  def reported_owner_address
    reported_owner_address_lines.join("\n")
  end

  def property_type
    element_by_id_content(property_table, '#PropertyTypeData')
  end

  def property_reported
    element_by_id_content(property_table, '#ctl00_ContentPlaceHolder1_PropertyReportData')
  end

  def cash_report_from_html
    element_by_id_content(notice_table, '#AmountData')
  end

  def cash_report_from_html_decimal
    begin
      BigDecimal(cash_report_from_html.split("\n").first.sub('$', ''))
    rescue
      Rails.logger.error("Error finding cash report for #{id}")
      BigDecimal(0)
    end
  end

  def reported_by
    element_by_id_content(property_table, '#ReportedByData')
  end

  def last_contacted_on
    Chronic.parse(element_by_id_content(notice_table, '#DateOfLastContactData')).to_date
  end

  def reported_on_from_html
    begin
      Chronic.parse(element_by_id_content(notice_table, '#DateReportedData')).to_date
    rescue
      Rails.logger.error("Error finding reported on for #{id}")
      nil
    end
  end

  def self.csv_column_names
    %w(rec_id id_number owner_names reported_owner_address property_type cash_report reported_by reported_on property_url_by_id_number notice_url_by_rec_id)
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

  def self.populate_fields
    Property.found.where(:cash_report => nil).find_in_batches(:batch_size => 1000) do |batches|
      batches.each do |property|
        property.cash_report = property.cash_report_from_html_decimal
        property.save
      end
    end

    Property.found.where(:reported_on => nil).find_in_batches(:batch_size => 1000) do |batches|
      batches.each do |property|
        next unless property.reported_on_from_html.present?

        property.reported_on = property.reported_on_from_html
        property.save
      end
    end

    Property.property_found.where(:id_number => nil).find_in_batches(:batch_size => 1000) do |batches|
      batches.each do |property|
        next unless property.id_number_from_html.present?

        property.id_number = property.id_number_from_html
        property.save
      end
    end
  end

  def self.quick_report
    File.open('report.txt', 'w') do |writer|
      writer.write "Found:\n"
      writer.write "  Notice and Property: #{Property.found.count}\n"
      writer.write "  Notice without Property: #{Property.notice_found.property_not_found.count}\n"
      writer.write "  Property without Notice: #{Property.property_found.notice_not_found.count}\n"
      writer.write "  Not found: #{Property.not_found.count}\n"

      without_cash = Property.found.where(:cash_report => BigDecimal(0)).count
      writer.write "Cash reported:\n"
      writer.write "  Max: #{Property.found.maximum(:cash_report)}\n"
      writer.write "  Avg: #{Property.found.where('cash_report > ?', BigDecimal(0)).average(:cash_report)}\n"
      writer.write "  No value: #{without_cash}\n"

      dates = Property.found.where('reported_on > ?', 100.years.ago)
      writer.write "Reported on:\n"
      writer.write "  Earliest: #{dates.minimum(:reported_on)}\n"
      writer.write "  Latest: #{dates.maximum(:reported_on)}\n"
    end
  end

  def self.download_random_by_rec_id(number=1000)
    number.times do
      rec_id = random_rec_id

      property = Property.where(:rec_id => rec_id).first
      if property.nil?
        property = Property.new(:rec_id => rec_id)
        property.save
      end

      next if property.notice_table_html.present? && property.property_table.present?

      property.delay.download
    end
  end

  def self.random_walk_by_rec_id(lower, upper, sample)
    counts = {}
    lower.upto(upper).each do |million|
      a = million * 1000000
      b = (million + 1) * 1000000

      found = sample.times.collect { notice_found_by_rec_id?(rand(a..b)) }.select { |x| x }.count

      counts[a] = found
    end

    counts
  end

  def self.notice_found_by_rec_id?(rec_id)
    url = "http://scoweb.sco.ca.gov/UCP/NoticeDetails.aspx?propertyRecID=#{rec_id}"

    response = response_for_url(url)

    response.present? && !response.include?('NO MATCH') && response.include?('Notice_Details_Main_Page_Content_Formatting_Table')
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

  def download
    Rails.logger.info("Trying to find propertyRecID #{rec_id}")

    self.downloaded_at = Time.now
    self.save!

    [
      {
        :url => notice_url_by_rec_id,
        :selector => '#Notice_Details_Main_Page_Content_Formatting_Table',
        :setter => :notice_table_html=
      },
      {
        :url => property_url_by_rec_id,
        :selector => '#Property_Details_Main_Page_Content_Formatting_Table',
        :setter => :property_table_html=
      }
    ].each do |data|
      table = Property.get_table(data[:url], data[:selector])
      if table.present?
        self.send(data[:setter], table.to_html)
        self.save
      end
    end
  end
end