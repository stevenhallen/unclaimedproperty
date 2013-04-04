class UrlUtils
  def self.element_by_id(table, id)
    table.css(id).first
  end

  def self.element_by_id_content(table, id)
    element = element_by_id(table, id)
    element.content.strip if element.present?
  end

  def self.element_by_id_children_content(table, id)
    element_by_id(table, id).children.collect do |element|
      element.content.strip
    end.select(&:present?)
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

  def self.get_table(url, table_selector)
    response = response_for_url(url)

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
end
