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

  def self.koala_error_str(e)
    str = "Koala #{e.fb_error_type}"
    str << " (code #{e.fb_error_code.to_s +
             (e.fb_error_subcode.nil? ? "" : ", subcode: " + e.fb_error_subcode.to_s)})"
    str << " HTTP status: #{e.http_status}" unless e.http_status.nil?
    str << "\n  #{e.fb_error_user_msg.nil? ? e.fb_error_message : e.fb_error_user_msg}"
    str << " (FB trace id: #{e.fb_error_trace_id})"

    str
  end

  def self.logout(global_options)
    if @@api.nil?
      @@api = init_api(global_options)
    end

    begin
      @@api.delete_object("me/permissions")
    rescue Koala::Facebook::APIError => e
      exit_now! koala_error_str e
    end
  end

  def self.request_object(global_options, id, options = {})
    if @@api.nil?
      @@api = init_api(global_options)
    end

    begin
      @@api.get_object(id, options) do |data|
        yield data
      end
    rescue Koala::Facebook::APIError => e
      exit_now! koala_error_str e
    end
  end

  def self.request_personal_connections(global_options, cmd)
    if @@api.nil?
      @@api = init_api(global_options)
    end

    begin
      data = @@api.get_connections("me", cmd)
    rescue Koala::Facebook::APIError => e
      exit_now! koala_error_str e
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

  def self.publish_post(global_options, msg)
    if @@api.nil?
      @@api = init_api(global_options)
    end

    begin
      profile_id, post_id = @@api.put_wall_post(msg)['id'].split '_', 2
    rescue Koala::Facebook::APIError => e
      exit_now! koala_error_str e
    end

    [profile_id, post_id]
  end

  def self.publish_link(global_options, msg, link_metadata)
    if @@api.nil?
      @@api = init_api(global_options)
    end

    begin
      profile_id, post_id = @@api.put_wall_post(msg, link_metadata)['id'].split '_', 2
    rescue Koala::Facebook::APIError => e
      exit_now! koala_error_str e
    end

    [profile_id, post_id]
  end

  def self.publish_photo(global_options, msg, image_file_or_url)
    if @@api.nil?
      @@api = init_api(global_options)
    end

    begin
      result = @@api.put_picture(image_file_or_url, {:message => msg})
      profile_id, post_id = result['post_id'].split '_', 2
    rescue Koala::Facebook::APIError => e
      exit_now! koala_error_str e
    end

    [profile_id, post_id]
  end
end