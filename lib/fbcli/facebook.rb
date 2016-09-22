require 'koala'

module FBCLI
  def self.init_api(global_options)
    # Access token passed from the command line takes precedence
    if not global_options[:token].nil?
      $config['access_token'] = global_options[:token]
    end

    if $config['access_token'].nil? or $config['access_token'].empty?
      exit_now! "You must first acquire an access token; run: #{APP_NAME} login"
    end

    Koala::Facebook::API.new($config['access_token'])
  end

  def self.request_data(global_options, cmd)
    api = init_api(global_options)

    begin
      data = api.get_connections("me", cmd)
    rescue Koala::Facebook::APIError => e
      exit_now! \
        "Koala #{e.fb_error_type} (code #{e.fb_error_code})" +
        if not e.http_status.nil? then " HTTP status: #{e.http_status}" else "" end +
        "\n  #{e.fb_error_message}"
    end

    data
  end

  def self.page_items(global_options, cmd)
    items = request_data(global_options, cmd)

    while not items.nil? do
      items.each { |item|
        yield item
      }

      items = items.next_page
    end
  end
end