require 'koala'

module FBCLI
  @@api = nil

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

  def self.request_object(global_options, id, options = {})
    if @@api.nil?
      @@api = init_api(global_options)
    end

    @@api.get_object(id, options) do |data|
      yield data
    end
  end

  def self.request_personal_connections(global_options, cmd)
    if @@api.nil?
      @@api = init_api(global_options)
    end

    begin
      data = @@api.get_connections("me", cmd)
    rescue Koala::Facebook::APIError => e
      exit_now! \
        "Koala #{e.fb_error_type} (code #{e.fb_error_code})" +
        if not e.http_status.nil? then " HTTP status: #{e.http_status}" else "" end +
        "\n  #{e.fb_error_message}"
    end

    data
  end

  def self.page_items(global_options, cmd, separator = nil, filter = nil)
    items = request_personal_connections(global_options, cmd)

    virgin = true
    count = 0

    while not (items.nil? or count == global_options['pages'].to_i) do
      items.each_with_index { |item, idx|
        if filter.nil? or not filter.call(item)
          unless separator.nil? or virgin
            puts separator
          end

          yield item

          virgin = false
        end
      }

      count += 1
      items = items.next_page
    end
  end
end