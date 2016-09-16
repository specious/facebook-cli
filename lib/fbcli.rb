require 'gli'
require 'yaml'
require 'fbcli/auth'
require 'fbcli/facebook'

CONFIG_FILE = "config.yml"

include GLI::App

program_desc "Facebook command line interface"

flag [:token], :desc => 'Provide Facebook access token', :required => false

pre do
  $config = YAML.load_file(CONFIG_FILE)
end

desc "Log into Facebook and receive an access token"
command :login do |c|
  c.action do
    token, expiration = FBCLI::listen_for_auth_code($config['app_id'], $config['app_secret'])

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

desc "List the pages you have 'Liked'"
command :likes do |c|
  c.action do |global_options,options,args|
    FBCLI::do_request global_options, "likes" do |item|
      puts item["name"]
      puts "https://www.facebook.com/#{item["id"]}/"
      puts
    end
  end
end

desc "List the people you are friends with (some limitations)"
command :friends do |c|
  c.action do |global_options,options,args|
    FBCLI::do_request global_options, "invitable_friends" do |item|
      puts item["name"]
    end
  end
end

consumePhoto = Proc.new do |item|
  puts item["name"] unless not item.key?("name")
  puts "https://www.facebook.com/#{item["id"]}/"
  puts "Created: #{Time.parse(item["created_time"]).httpdate}"
  puts "--"
end

desc "List photos you have uploaded"
command :photos do |c|
  c.action do |global_options,options,args|
    FBCLI::do_request global_options, "photos?type=uploaded", &consumePhoto
  end
end

desc "List photos you are tagged in"
command :photosof do |c|
  c.action do |global_options,options,args|
    FBCLI::do_request global_options, "photos", &consumePhoto
  end
end

exit run(ARGV)