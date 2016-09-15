require 'koala'

module FBCLI
  def self.ensure_access_token(global_options)
    if not global_options[:token].nil?
      $config['access_token'] = global_options[:token]
    end

    if $config['access_token'].nil? or $config['access_token'].empty?
      exit_now! "You must first acquire an access token; run: #{$0} login"
    end
  end

  def self.do_request(global_options, cmd)
    ensure_access_token(global_options)

    graph = Koala::Facebook::API.new($config['access_token'])

    begin
      items = graph.get_connections("me", cmd)
    rescue Koala::Facebook::APIError => e
      exit_now! "Koala exception: #{e}"
    end

    while not items.nil? do
      items.each { |item|
        yield item
      }

      items = items.next_page
    end
  end
end