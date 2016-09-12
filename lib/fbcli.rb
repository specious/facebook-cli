require 'yaml'
require 'koala'
require 'fbcli/auth'

CONFIG_FILE = "config.yml"

if ARGV[0] == "--help"
  puts "Usage: #{$0} [login | <access_token>]"
  exit
end

$config = YAML.load_file(CONFIG_FILE)

if ARGV[0] == "login"
  token, expiration = FBCLI::listen_for_auth_code($config['app_id'], $config['app_secret'])

  if not token.nil?
    $config['access_token'] = token

    File.open(CONFIG_FILE,'w') do |f|
      f.write $config.to_yaml
    end

    puts "Your access token: #{$access_token}"
    puts
    puts "Expires in: #{Time.at(expiration).utc.strftime("%H:%M")} hours"
    puts
    puts "Have fun!"
  end

  exit
end

if not ARGV[0].nil?
  $config['access_token'] = ARGV[0]
end

graph = Koala::Facebook::API.new($config['access_token'])

begin
  likes = graph.get_connections("me", "likes")
rescue Koala::Facebook::APIError => e
  puts "Koala exception: #{e}"
  exit
end

while not likes.nil? do
  likes.each { |like|
    puts like["name"]
    puts "https://www.facebook.com/#{like["id"]}/"
    puts
  }

  likes = likes.next_page
end