require 'gli'
require 'yaml'
require 'koala'
require 'optparse'
require 'fbcli/auth'

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
    if not global_options[:token].nil?
      $config['access_token'] = global_options[:token]
    end

    if $config['access_token'].nil? or $config['access_token'].empty?
      exit_now! "You must first acquire an access token; run: #{$0} login"
    end

    graph = Koala::Facebook::API.new($config['access_token'])

    begin
      likes = graph.get_connections("me", "likes")
    rescue Koala::Facebook::APIError => e
      exit_now! "Koala exception: #{e}"
    end

    while not likes.nil? do
      likes.each { |like|
        puts like["name"]
        puts "https://www.facebook.com/#{like["id"]}/"
        puts
      }

      likes = likes.next_page
    end
  end
end

exit run(ARGV)