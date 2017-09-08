require 'net/http'
require 'uri'
require 'webrick'
require 'json'

module FBCLI
  API_VERSION = "2.8"

  def self.listen_for_auth_code(port, app_id, app_secret)
    uri = "https://www.facebook.com/dialog/oauth?client_id=#{app_id}" +
      "&redirect_uri=http://localhost:#{port}/" +
      "&scope=user_likes,user_friends,user_posts,user_photos,user_videos,user_events,publish_actions"

    puts <<-EOM
Request permission to use the Facebook API by opening this link in your browser:

#{uri}

Waiting for authorization code on port #{port}...

    EOM

    server = WEBrick::HTTPServer.new(
      :Port => port,
      :SSLEnable => false,
      :Logger => WEBrick::Log.new(File.open(File::NULL, 'w')),
      :AccessLog => []
    )

    access_token = nil

    server.mount_proc '/' do |req, res|
      key, value = req.query_string.split '=', 2

      if key == "code"
        access_token = get_access_token(port, app_id, value, app_secret)
      else
        puts "Received unexpected request: #{req.query_string}"
        # TODO: Handle forseeable cases
      end

      res.body = 'You may now close this window.'
      server.shutdown
    end

    # Allow CTRL+C intervention
    trap 'INT' do server.shutdown end

    # This thread will block execution until server shuts down
    server.start

    # Return access token
    access_token
  end

  def self.get_access_token(port, app_id, auth_code, app_secret)
    auth_uri = "https://graph.facebook.com/v#{API_VERSION}/oauth/access_token?" +
      "client_id=#{app_id}" +
      "&redirect_uri=http://localhost:#{port}/" +
      "&client_secret=#{app_secret}" +
      "&code=#{auth_code}"

    res = Net::HTTP.get_response(URI.parse(auth_uri))
    res = JSON.parse(res.body)

    res["access_token"]
  end
end