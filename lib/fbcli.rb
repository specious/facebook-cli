require 'yaml'
require 'koala'
require 'fbcli/auth'

if ARGV[0].nil?
  puts "Usage: #{$0} [login | <access_token>]"
  exit
end

$config = YAML.load_file("config.yml")

if ARGV[0] == "login"
  $access_token = ""
  FBCLI::listen_for_auth_code($config['app_id'], $config['app_secret'])
else
  $access_token = ARGV[0]
end

graph = Koala::Facebook::API.new($access_token)
likes = graph.get_connections("me", "likes")

while not likes.nil? do
  likes.each { |like|
    puts like["name"]
    puts "https://www.facebook.com/#{like["id"]}/"
    puts
  }

  likes = likes.next_page
end