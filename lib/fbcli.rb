require 'gli'
require 'yaml'
require 'fbcli/auth'
require 'fbcli/format'
require 'fbcli/facebook'

CONFIG_FILE = "config.yml"

include GLI::App

program_desc "Facebook command line interface"

flag [:token], :desc => 'Provide Facebook access token', :required => false
flag [:format], :desc => 'Output format (values: text, html)', :default_value => "text"

pre do |global_options,command|
  $config = YAML.load_file(CONFIG_FILE)

  if $config['app_id'].nil? or $config['app_secret'].nil?
    exit_now! <<~EOM
      It looks like you are running #{$0} for the first time.

      The following steps are necessary to use the Facebook API:

      - Create a new application at: https://developers.facebook.com/apps
      - In the Settings tab, add "localhost" to the App Domains
      - Save the App ID and App Secret in "config.yml"

      After that, run: #{$0} login
    EOM
  end

  $format = global_options[:format]

  if $format == "html" and command.name != :login
    puts <<~EOM
      <!doctype html>
      <html lang=en>
      <head>
        <meta charset=utf-8>
      </head>
      <body>
    EOM
  end

  # Success
  true
end

post do |global_options,command|
  if $format == "html" and command.name != :login
    puts <<~EOM
      </body>
      </html>
    EOM
  end
end

on_error do |exception|
  puts exception.message

  # Suppress GLI's built-in error handling
  false
end

desc "Log into Facebook and receive an access token"
command :login do |c|
  c.flag [:port], :desc => 'Local TCP port to serve Facebook login redirect page', :default_value => '3333'
  c.action do |global_options,options,args|
    token, expiration = FBCLI::listen_for_auth_code(options['port'], $config['app_id'], $config['app_secret'])

    if not token.nil?
      $config['access_token'] = token

      File.open(CONFIG_FILE,'w') do |f|
        f.write $config.to_yaml
      end

      puts "Your access token: #{token}"
      puts
      puts "Expires in: #{Time.at(expiration).utc.strftime("%H:%M")} hours"
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

exit run(ARGV)