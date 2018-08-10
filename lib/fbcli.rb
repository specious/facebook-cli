require 'gli'
require 'yaml'
require 'json'
require 'jsonpath'
require 'fbcli/api'
require 'fbcli/auth'
require 'fbcli/version'

APP_NAME    = File.basename($0, File.extname($0))
CONFIG_FILE = File.join(ENV['HOME'], ".#{APP_NAME}rc")

include GLI::App

program_desc "Facebook command line interface"

version FBCLI::VERSION

flag [:token], :desc => 'Provide Facebook access token', :required => false
flag [:pages, :p], :desc => 'Maximum number of pages of results to retrieve', :required => false, :type => Integer, :default_value => -1

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
  # Make global options officially global
  $global_options = global_options

  # Exit gracefully when terminating due to a broken pipe
  Signal.trap "PIPE", "SYSTEM_DEFAULT" if Signal.list.include? "PIPE"

  if command.name == :config
    $config = {}
  else
    begin
      $config = YAML.load_file(CONFIG_FILE)
    rescue
      exit_now! <<-EOM
It looks like you are running #{APP_NAME} for the first time.

Run `#{APP_NAME} config` for setup instructions.
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

# Trap exceptions bubbling up from GLI and provide an alternative handler
on_error do |exception|
  puts exception.message

  # Suppress GLI's built-in error handling
  false
end

# Update instructions in README.md when these change
SETUP_INSTRUCTIONS = <<-EOM
You must create and configure a Facebook application to interact with the Graph API.

- Create a new application at: https://developers.facebook.com/apps
- Under "PRODUCTS" in the left sidebar:
  - Click "+ Add Product"
  - Choose "Facebook Login" by clicking its "Set Up" button
  - Don't bother choosing a platform, instead click "Settings" under "Facebook Login" in the side bar
  - Under "Client OAuth Settings", switch "Use Strict Mode for Redirect URIs" to "No"
  - Under "Valid OAuth redirect URIs", add: "http://localhost:3333/"
      (or your host identifier and port number, to receive auth code during authentication)
  - Click "Save Changes"
- In the "App Review" tab:
  - Flip the switch to make your app live
  - Choose a category (any one will do)
  - Click "Confirm"
- In the "Dashboard" tab:
  - Click "Show" to reveal your app secret
  - Save the App ID and App Secret by running:

    #{APP_NAME} config --appid=<app-id> --appsecret=<app-secret>

Obtain an access token by running:

    #{APP_NAME} login

If authenticating on a remote machine or using a different port to receive the auth code:

    #{APP_NAME} login --host <hostname-or-ip> --port <port>
EOM

desc "Save your Facebook API credentials"
command :config do |c|
  c.flag [:appid], :desc => 'Facebook application ID', :default_value => ""
  c.flag [:appsecret], :desc => 'Facebook application secret', :default_value => ""
  c.action do |global_options, options|
    if options['appid'].empty? or options['appsecret'].empty?
      exit_now! SETUP_INSTRUCTIONS
    end

    $config['app_id'] = options['appid'].to_i
    $config['app_secret'] = options['appsecret']

    save_config

    puts "Configuration saved to #{CONFIG_FILE}"
    puts
    puts "To obtain a Facebook access token, run: #{APP_NAME} login"
  end
end

desc "Request Facebook permissions and receive an API access token"
long_desc %(
  Print a URL that launches a request to Facebook to allow the app you've created (by
  following the setup instructions) to perform Facebook Graph actions on your behalf,
  and start an HTTP server to listen for the authorization code.

  Upon receiving the authorization code, immediately trade it in for an access
  token and save it to a configuration file.

  See: https://www.oauth.com/oauth2-servers/access-tokens/

  Attention: if you choose to listen for the authorization token on a port number
  different from the default value or your host identifier is different from
  "localhost", make sure that in your app settings the same host and port are
  specified under:

  - PRODUCTS > Facebook Login > Client OAuth Settings > Valid OAuth redirect URIs
)
command :login do |c|
  c.flag [:host], :desc => 'This machine\'s host identifier (host name or IP address)', :default_value => 'localhost'
  c.flag [:port], :desc => 'Local TCP port to listen for authorization code', :default_value => '3333'
  c.switch [:info], :desc => 'Show information about the current access token and exit', :negatable => false
  c.action do |global_options, options|
    if options['info']
      if $config['access_token'].nil?
        puts "Either provide an access token via the --token parameter or obtain one by running:"
        puts
        puts "  #{APP_NAME} login"
      else
        begin
          puts "Your access token: #{$config['access_token']}"
          puts

          FBCLI::request_token_info do |data|
            puts "It was issued on: #{date_str(data['issued_at'])}"
            puts
            puts "It is valid until: #{date_str(data['expires_at'])}"
            puts
            puts "Permissions:\n  - #{data['scopes'].join("\n  - ")}"
          end
        rescue
          puts "Your access token does not appear to be valid or may have expired."
        end
      end
    else
      token = FBCLI::login($config['app_id'], $config['app_secret'], options['host'], options['port'])

      if not token.nil?
        $config['access_token'] = token

        save_config

        puts "Your access token has been saved to #{CONFIG_FILE}"
        puts
        puts "To see it and find out when it is scheduled to expire, run:"
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

desc "Make a direct Facebook API request"
arg_name "request"
long_desc %(
  For example, try:

    #{APP_NAME} api "me?fields=name,email,birthday"

  To view the list of fields that can be queried:

    #{APP_NAME} api "me?metadata=1"

  Retrieve a specific value using --get:

    #{APP_NAME} api --get name me

  Retrieve nested values using the JsonPath query language:

    #{APP_NAME} api --get "metadata.fields..name" "me?metadata=1"
)
command :api do |c|
  c.flag [:get], :desc => "Extract a value from the JSON response by means of a JsonPath query"
  c.switch [:raw], :desc => 'Output unformatted JSON', :negatable => false
  c.action do |global_options, options, args|
    # If no query provided, offer guidance
    if args[0].nil? || args[0].empty?
      # TODO: Show usage instructions
      #
      #  GLI provides a function help_now! which normally prints usage instructions and exits,
      #  however the way it triggers that eventuality is by raising an option parser exception,
      #  which in turn results in the default handler printing usage instructions. Unfortunately,
      #  since facebook-cli provides an alternative exception handler and breaks that functionality,
      #  it will take further engineering to effect the desired behavior.

      exit_now! "See documentation: #{APP_NAME} help api"
    end

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

    # Nicely format JSON result if --raw flag is not set
    unless options['raw']
      # It appears that Hash and Koala::Facebook::API::GraphCollection objects
      # are JSON, while Array results are not.
      #
      # TODO: This heuristic could stand to be revised or better documented
      if res.class != Array
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

desc "List pages you have 'Liked'"
command :likes do |c|
  c.action do
    FBCLI::page_items 'likes', '' do |item|
      puts item["name"]
      puts link item["id"]
    end
  end
end

desc "List posts on your timeline"
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

exit run(ARGV)