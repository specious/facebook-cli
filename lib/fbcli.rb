require 'gli'
require 'yaml'
require 'fbcli/auth'
require 'fbcli/format'
require 'fbcli/facebook'

APP_NAME = File.split($0)[1]
CONFIG_FILE = File.join(ENV['HOME'], ".#{APP_NAME}rc")

include GLI::App

program_desc "Facebook command line interface"

version '1.2.0'

flag [:token], :desc => 'Provide Facebook access token', :required => false
flag [:format], :desc => 'Output format (values: text, html)', :default_value => "text"

def print_header
  if $format == 'html'
    puts <<~EOM
      <!doctype html>
      <html lang=en>
      <head>
        <meta charset=utf-8>
      </head>
      <body>
    EOM
  end
end

def print_footer
  if $format == 'html'
    puts <<~EOM
      </body>
      </html>
    EOM
  end
end

formattable_commands = [
  :me,
  :likes,
  :feed,
  :friends,
  :photos,
  :photosof,
  :events,
  :pastevents
]

def save_config
  File.open(CONFIG_FILE, 'w') do |f|
    f.write $config.to_yaml
  end
end

pre do |global_options,command|
  if command.name == :config
    $config = {}
  else
    begin
      $config = YAML.load_file(CONFIG_FILE)
    rescue
      exit_now! <<~EOM
        It looks like you are running #{APP_NAME} for the first time.

        The following steps are necessary to use the Facebook API:

        - Create a new application at: https://developers.facebook.com/apps
        - In the Settings tab, add "localhost" to the App Domains
        - Save the App ID and App Secret by running:

            #{APP_NAME} config --appid=<app-id> --appsecret=<app-secret>

        After that, acquire an access token by running:

            #{APP_NAME} login
      EOM
    end
  end

  $format = global_options[:format]

  if formattable_commands.include?(command.name)
    print_header
  end

  # Success
  true
end

post do |global_options,command|
  if formattable_commands.include?(command.name)
    print_footer
  end
end

on_error do |exception|
  puts exception.message

  # Suppress GLI's built-in error handling
  false
end

desc "Save Facebook application ID and secret"
command :config do |c|
  c.flag [:appid], :desc => 'Facebook application ID'
  c.flag [:appsecret], :desc => 'Facebook application secret'
  c.action do |global_options,options,args|
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
  c.action do |global_options,options,args|
    token, expiration = FBCLI::listen_for_auth_code(options['port'], $config['app_id'], $config['app_secret'])

    if not token.nil?
      $config['access_token'] = token

      save_config

      puts "Your access token: #{token}"
      puts
      puts "Expires in: #{FBCLI::expiration_str(expiration.to_i)}"
      puts
      puts "Have fun!"
    end
  end
end

desc "Show your name and profile ID"
command :me do |c|
  c.action do |global_options,options,args|
    data = FBCLI::request_data global_options, ""
    FBCLI::write "Name: #{data["name"]}"
    FBCLI::write "Your profile ID: #{data["id"]}"
  end
end

desc "List the pages you have 'Liked'"
command :likes do |c|
  c.action do |global_options,options,args|
    FBCLI::page_items global_options, "likes" do |item|
      FBCLI::write item["name"]
      FBCLI::write FBCLI::link item["id"]
      FBCLI::write
    end
  end
end

desc "List the people you are friends with (some limitations)"
long_desc <<~EOM
  As of Graph API v2.0 Facebook no longer provides access to your full friends list.
  As an alternative, we now request 'invitable_friends' which only includes friends
  you are allowed to invite to use your app.

  See: https://developers.facebook.com/docs/apps/faq#faq_1694316010830088
EOM
command :friends do |c|
  c.action do |global_options,options,args|
    FBCLI::page_items global_options, "invitable_friends" do |item|
      FBCLI::write item["name"]
    end
  end
end

desc "List the posts on your profile"
command :feed do |c|
  c.action do |global_options,options,args|
    FBCLI::page_items global_options, "feed" do |item|
      profile_id, post_id = item["id"].split '_', 2

      FBCLI::write item["message"] if item.has_key?("message")
      FBCLI::write FBCLI::link "#{profile_id}/posts/#{post_id}"
      FBCLI::write "Created: #{FBCLI::date(item["created_time"])}"
      FBCLI::write "--"
    end
  end
end

consumePhoto = Proc.new do |item|
  FBCLI::write item["name"] unless not item.key?("name")
  FBCLI::write FBCLI::link "#{item["id"]}"
  FBCLI::write "Created: #{FBCLI::date(item["created_time"])}"
  FBCLI::write "--"
end

desc "List photos you have uploaded"
command :photos do |c|
  c.action do |global_options,options,args|
    FBCLI::page_items global_options, "photos?type=uploaded", &consumePhoto
  end
end

desc "List photos you are tagged in"
command :photosof do |c|
  c.action do |global_options,options,args|
    FBCLI::page_items global_options, "photos", &consumePhoto
  end
end

def list_events(global_options, past = false)
  now = Time.new

  FBCLI::page_items global_options, "events" do |item|
    starts = Time.parse(item['start_time'])

    if (past and starts < now) ^ (not past and starts > now)
      unless item['end_time'].nil?
        ends = Time.parse(item['end_time'])
        duration = ends - starts
      end

      FBCLI::write "#{item['name']} (#{item['id']})"
      FBCLI::write
      FBCLI::write "Location: #{item['place']['name']}" unless item['place'].nil?
      FBCLI::write "Date: #{FBCLI::date(item['start_time'])}"
      FBCLI::write "Duration: #{duration / 3600} hours" if defined?(duration) and not duration.nil?
      FBCLI::write "RSVP: #{item['rsvp_status'].sub(/unsure/, 'maybe')}"
      FBCLI::write
      FBCLI::write FBCLI::link "events/#{item['id']}"
      FBCLI::write
      FBCLI::write item['description']
      FBCLI::write "---------------------------------"
    end
  end
end

desc "List your upcoming events"
command :events do |c|
  c.action do |global_options,options,args|
    list_events global_options
  end
end

desc "List your past events"
command :pastevents do |c|
  c.action do |global_options,options,args|
    list_events global_options, true
  end
end

exit run(ARGV)