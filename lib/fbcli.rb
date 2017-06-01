require 'gli'
require 'yaml'
require 'json'
require 'jsonpath'
require 'fbcli/auth'
require 'fbcli/version'
require 'fbcli/facebook'

APP_NAME    = File.basename($0, File.extname($0))
CONFIG_FILE = File.join(ENV['HOME'], ".#{APP_NAME}rc")

include GLI::App

program_desc "Facebook command line interface"

version FBCLI::VERSION

flag [:token], :desc => 'Provide Facebook access token', :required => false
flag [:pages, :p], :desc => 'Max pages', :required => false, :type => Integer, :default_value => -1

def link(path)
  "https://www.facebook.com/#{path}"
end

def link_to_post(full_post_id)
  profile_id, post_id = full_post_id.split '_', 2
  link "#{profile_id}/posts/#{post_id}"
end

# Facebook returns dates in ISO 8601 or unix timestamp format
def date_str(date)
  t = (date.is_a? Integer) ? Time.at(date) : Time.parse(date).localtime

  # Convert to human friendly representation in user's time zone (almost RFC 2822)
  t.strftime('%a, %-d %b %Y %H:%M:%S %Z')
end

def save_config
  File.open(CONFIG_FILE, 'w') do |f|
    f.write $config.to_yaml
  end
end

pre do |global_options, command|
  $global_options = global_options # They're supposed to be global, right?

  # Do not print stack trace when terminating due to a broken pipe
  Signal.trap "SIGPIPE", "SYSTEM_DEFAULT"

  if command.name == :config
    $config = {}
  else
    begin
      $config = YAML.load_file(CONFIG_FILE)
    rescue
      exit_now! <<-EOM
It looks like you are running #{APP_NAME} for the first time.

To interact with the Facebook API you must create and configure
a new Facebook application for your personal use.

- Create a new application at: https://developers.facebook.com/apps
- In the Settings tab:
  - Click "Add Platform" and select "Website"
  - Set "Site URL" to "http://localhost"
  - Under "App Domains" add "localhost"
  - Click "Save"
- In the "App Review" tab:
  - Flip the switch to make your app live
- In the "Dashboard" tab:
  - Click "Show" to reveal your app secret
  - Save the App ID and App Secret by running:

    #{APP_NAME} config --appid=<app-id> --appsecret=<app-secret>

After that, acquire an access token by running:

    #{APP_NAME} login
      EOM
    end
  end

  # Let access token passed from the command line take precedence
  if not global_options[:token].nil?
    $config['access_token'] = global_options[:token]
  end

  # Success
  true
end

on_error do |exception|
  puts exception.message

  # Suppress GLI's built-in error handling
  false
end

desc "Save Facebook application ID and secret"
command :config do |c|
  c.flag [:appid], :desc => 'Facebook application ID', :required => true
  c.flag [:appsecret], :desc => 'Facebook application secret', :required => true
  c.action do |global_options, options|
    $config['app_id'] = options['appid'].to_i
    $config['app_secret'] = options['appsecret']

    save_config

    puts "Configuration saved to #{CONFIG_FILE}"
    puts
    puts "To acquire a Facebook access token, run: #{APP_NAME} login"
  end
end

desc "Log into Facebook and receive an access token"
command :login do |c|
  c.flag [:port], :desc => 'Local TCP port to serve Facebook login redirect page', :default_value => '3333'
  c.switch [:info], :desc => 'Show information about the current access token and exit', :negatable => false
  c.action do |global_options, options|
    if options['info']
      begin
        FBCLI::request_token_info do |data|
          puts "Your access token was issued on: #{date_str(data['issued_at'])}"
          puts
          puts "It is valid until: #{date_str(data['expires_at'])}"
          puts
          puts "Permissions:\n  - #{data['scopes'].join("\n  - ")}"
        end
      rescue
        puts "Your access token does not appear to be valid for this application."
      end
    else
      token = FBCLI::listen_for_auth_code(options['port'], $config['app_id'], $config['app_secret'])

      if not token.nil?
        $config['access_token'] = token

        save_config

        puts "Your access token: #{token}"
        puts
        puts "To find out when it is scheduled to expire, run:"
        puts
        puts "  #{APP_NAME} login --info"
        puts
        puts "Have fun!"
      end
    end
  end
end

desc "Deauthorize your access token"
command :logout do |c|
  c.action do
    FBCLI::logout
    puts "You are now logged out."
  end
end

desc "Make a Facebook API request"
arg_name "request"
long_desc %(
  This is similar to the online tool:

    https://developers.facebook.com/tools/explorer

  For example, try:

    #{APP_NAME} api "165795193558366?fields=name,about,website"

  To view the list of valid fields you can request, ask for the metadata:

    #{APP_NAME} api "165795193558366?metadata=1"

  Moreover, you can extract a value from the response using --get. For example:

    #{APP_NAME} api --get name 165795193558366

  Use JsonPath language to retrieve nested values. For example:

    #{APP_NAME} api --get "metadata.fields..name" "165795193558366?metadata=1"

  Some valid requests may not be honored or return incomplete results due to
  insufficient permissions, which were established during the authentication
  process.
)
command :api do |c|
  c.flag [:get], :desc => "Extract a particular value from the JSON response"
  c.switch [:raw], :desc => 'Output unformatted JSON', :negatable => false
  c.action do |global_options, options, args|
    res = FBCLI::raw_request args[0]

    # Extract value(s) using JsonPath
    if options['get']
      path = JsonPath.new("$.#{options['get']}")
      res = path.on(res)

      # If the result is a JSON structure, unwrap it
      if res[0].class == Hash
        res = res[0]
      end
    end

    # Nicely format JSON result if not --raw
    unless options['raw']
      if res.class == Hash
        res = JSON.pretty_generate res
      end
    end

    puts res
  end
end

desc "Show your profile information"
command :me do |c|
  c.action do
    FBCLI::request_object "me" do |data|
      puts "Name: #{data["name"]} (#{data["id"]})"
      puts "Picture: http://graph.facebook.com/#{data["id"]}/picture?type=large"
    end
  end
end

desc "Some useful URLs"
command :links do |c|
  c.action do
    puts "A few URLs Facebook doesn't want you to know:"
    puts
    puts "Manage application settings"
    puts "  https://www.facebook.com/settings?tab=applications"
    puts
    puts "Photos"
    puts "  https://www.facebook.com/me/photos_albums"
    puts
    puts "Activity log"
    puts "  https://www.facebook.com/me/allactivity"
    puts
    puts "Search Facebook"
    puts "  https://www.facebook.com/search/top/?q=ethereum"
    puts
    puts "Edit a video"
    puts "  https://www.facebook.com/video/edit/?v=VIDEO_ID"
    puts
    puts "Graph API explorer"
    puts "  https://developers.facebook.com/tools/explorer/"
    puts
    puts "Sharing debugger"
    puts "  https://developers.facebook.com/tools/debug/"
  end
end

desc "Post a message or image to your timeline"
arg_name "message"
long_desc %(
  Facebook advises: photos should be less than 4 MB and saved as JPG, PNG, GIF or TIFF files.
)
command :post do |c|
  c.flag [:i, :image], :desc => 'File or URL of image to post'
  c.flag [:g, :groupid], :desc => 'Group id for post'
  c.action do |global_options, options, args|
    if not options['groupid'].nil?
      full_post_id = FBCLI::publish_post_group args[0], options['groupid']
    end
    if not options['image'].nil?
      full_post_id = FBCLI::publish_image args[0], options['image']
    else
      full_post_id = FBCLI::publish_post args[0]
    end

    puts "Your post: #{link_to_post full_post_id}"
  end
end

desc "Post a video to your timeline"
arg_name "message"
long_desc %(
  Facebook advises: aspect ratio must be between 9x16 and 16x9. The following formats are
  supported:

  3g2, 3gp, 3gpp, asf, avi, dat, divx, dv, f4v, flv, m2ts, m4v,
  mkv, mod, mov, mp4, mpe, mpeg, mpeg4, mpg, mts, nsv, ogm, ogv, qt, tod,
  ts, vob, and wmv
)
command :postvideo do |c|
  c.flag [:v, :video], :desc => 'File or URL of video'
  c.flag [:t, :title], :desc => 'Title'
  c.action do |global_options, options, args|
    video_id = FBCLI::publish_video args[0], options['video'], options['title']
    puts "Your post: #{link video_id}"
    puts "Edit your video: #{link "video/edit/?v=#{video_id}"}"
    puts
    puts "It might take a few minutes for your video to become available."
  end
end

desc "Post a link to your timeline"
arg_name "url"
command :postlink do |c|
  c.flag [:m, :message], :desc => 'Main message'
  c.flag [:n, :name], :desc => 'Link name'
  c.flag [:d, :description], :desc => 'Link description'
  c.flag [:c, :caption], :desc => 'Link caption'
  c.flag [:i, :image], :desc => 'Link image URL'
  c.action do |global_options, options, args|
    link_metadata = {
      "name" => options['name'],
      "link" => args[0],
      "caption" => options['caption'],
      "description" => options['description'],
      "picture" => options['image']
    }

    full_post_id = FBCLI::publish_post options['message'], link_metadata

    puts "Your post: #{link_to_post full_post_id}"
  end
end

desc "List pages you have 'Liked'"
command :likes do |c|
  c.action do
    FBCLI::page_items 'likes', '' do |item|
      puts item["name"]
      puts link item["id"]
    end
  end
end

desc "List people you are friends with (some limitations)"
long_desc %(
  As of Graph API v2.0 Facebook no longer provides access to your full friends list.
  As an alternative, we now request 'taggable_friends' which only includes friends
  you are allowed to tag.

  See: https://developers.facebook.com/docs/apps/faq#faq_1694316010830088
)
command :friends do |c|
  c.action do
    FBCLI::page_items 'taggable_friends' do |item|
      puts item['name']
    end
  end
end

desc "List posts on your profile"
command :feed do |c|
  c.action do
    FBCLI::page_items "feed", '- - -' do |item|
      puts item["message"] if item.has_key?("message")
      puts
      puts link_to_post item["id"]
      puts "Created: #{date_str(item["created_time"])}"
    end
  end
end

desc "List stories you are tagged in"
command :tagged do |c|
  c.switch [:date], :desc => 'Include date you were tagged on'
  c.action do |global_options, options|
    FBCLI::page_items 'tagged', '- - -' do |item|
      if item["story"]
        puts "### #{item["story"]}"
        puts
      end
      puts item["message"] if item.has_key?("message")
      puts
      puts link_to_post item["id"]
      puts "Tagged on: #{date_str(item["tagged_time"])}" if options['date']
    end
  end
end

handlePhoto = Proc.new do |item|
  puts "#{item["name"]}\n\n" unless not item.key?("name")
  puts link "#{item["id"]}"
  puts "Created: #{date_str(item["created_time"])}"
end

desc "List photos you have uploaded"
command :photos do |c|
  c.action do
    FBCLI::page_items "photos?type=uploaded", '- - -', &handlePhoto
  end
end

desc "List photos you are tagged in"
command :photosof do |c|
  c.action do
    FBCLI::page_items "photos", '- - -', &handlePhoto
  end
end

handleVideo = Proc.new do |item|
  puts "#{item["description"]}\n\n" unless not item.key?("description")
  puts link "#{item["id"]}"
  puts "Updated: #{date_str(item["updated_time"])}"
end

desc "List videos you have uploaded"
command :videos do |c|
  c.action do
    FBCLI::page_items "videos?type=uploaded", '- - -', &handleVideo
  end
end

desc "List videos you are tagged in"
command :videosof do |c|
  c.action do
    FBCLI::page_items "videos", '- - -', &handleVideo
  end
end

def list_events(past = false)
  now = Time.new

  filter = lambda { |item|
    starts = Time.parse(item['start_time'])
    not ((past and starts < now) ^ (not past and starts > now))
  }

  FBCLI::page_items "events", '- - -', filter do |item|
    starts = Time.parse(item['start_time'])

    unless item['end_time'].nil?
      ends = Time.parse(item['end_time'])
      duration = ends - starts
    end

    puts "#{item['name']} (#{item['id']})"
    puts
    puts "Location: #{item['place']['name']}" unless item['place'].nil?
    puts "Date: #{date_str(item['start_time'])}"
    puts "Duration: #{duration / 3600} hours" if defined?(duration) and not duration.nil?
    puts "RSVP: #{item['rsvp_status'].sub(/unsure/, 'maybe')}"
    puts
    puts link "events/#{item['id']}"
  end
end

desc "List your upcoming events"
command :events do |c|
  c.action do
    list_events
  end
end

desc "List your past events"
command :pastevents do |c|
  c.action do
    list_events true
  end
end

desc "Show event details"
arg_name "[ids...]"
command :event do |c|
  c.action do |global_options, options, args|
    args.each_with_index do |id, index|
      FBCLI::request_object(
        id,
        :fields => 'name,description,place,owner,start_time,end_time,attending_count,declined_count,maybe_count,is_canceled'
      ) do |item|
        starts = Time.parse(item['start_time'])

        unless item['end_time'].nil?
          ends = Time.parse(item['end_time'])
          duration = ends - starts
        end

        puts "#{item['name']} (#{item['id']})"

        puts
        puts "Location: #{item['place']['name']}" unless item['place'].nil?
        puts "Date: #{date_str(item['start_time'])}" + (item['is_canceled'] ? " [CANCELED]" : "")
        puts "Duration: #{duration / 3600} hours" if defined?(duration) and not duration.nil?
        puts "Created by: #{item['owner']['name']}"
        puts
        puts "Attending: #{item['attending_count']}"
        puts "Maybe: #{item['maybe_count']}"
        puts "Declined: #{item['declined_count']}"
        puts
        puts link "events/#{item['id']}"

        if not (item['description'].nil? || item['description'].empty?)
          puts
          puts item['description']
        end

        puts "- - -" unless index == args.size - 1
      end
    end
  end
end

exit run(ARGV)
