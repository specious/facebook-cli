require 'koala'

module FBCLI
  @@api = nil

  def self.init_api
    if $config['access_token'].nil? or $config['access_token'].empty?
      exit_now! "You must first acquire an access token; run: #{APP_NAME} login"
    end

    Koala::Facebook::API.new($config['access_token'])
  end

  def self.koala_error_str(e)
    str = "Koala #{e.fb_error_type}"
    str << " (code #{e.fb_error_code.to_s +
             (e.fb_error_subcode.nil? ? "" : ", subcode: " + e.fb_error_subcode.to_s)})"
    str << " HTTP status: #{e.http_status}" unless e.http_status.nil?
    str << "\n  #{e.fb_error_user_msg.nil? ? e.fb_error_message : e.fb_error_user_msg}"
    str << " (FB trace id: #{e.fb_error_trace_id})"

    str
  end

  def self.api_call(lambda)
    @@api = init_api if @@api.nil?

    begin
      lambda.call(@@api)
    rescue Koala::Facebook::APIError => e
      exit_now! koala_error_str e
    end
  end

  def self.logout
    api_call lambda { |api| api.delete_object("me/permissions") }
  end

  def self.request_object(id, options = {})
    api_call lambda { |api|
      api.get_object(id, options) do |data|
        yield data
      end
    }
  end

  def self.request_personal_connections(cmd)
    api_call lambda { |api|
      api.get_connections("me", cmd)
    }
  end

  def self.page_items(cmd, separator = nil, filter = nil)
    items = request_personal_connections(cmd)

    virgin = true
    count = 0

    while not (items.nil? or count == $global_options['pages']) do
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

  def self.publish_post(msg, link_metadata = {})
    result = api_call lambda { |api| api.put_wall_post(msg, link_metadata) }
    result['id']
  end

  def self.publish_image(msg, image_file_or_url)
    result = api_call lambda { |api| api.put_picture(image_file_or_url, {:message => msg}) }
    result['post_id']
  end
end