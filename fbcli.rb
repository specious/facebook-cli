#!/usr/bin/env ruby

require 'koala'

APP_ID = 326846274328543
ACCESS_TOKEN = ARGV[0]

@graph = Koala::Facebook::API.new(ACCESS_TOKEN)

likes = @graph.get_connections("me", "likes")

while not likes.nil? do
  likes.each { |like|
    puts like["name"]
    puts "https://www.facebook.com/#{like["id"]}/"
    puts
  }

  likes = likes.next_page
end