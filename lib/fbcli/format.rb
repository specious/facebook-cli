module FBCLI
  # Facebook returns dates in ISO 8601 format
  def self.date(fb_date)
    Time.parse(fb_date).localtime.rfc2822
  end

  def self.link(path, format = $format)
    url = "https://www.facebook.com/#{path}"

    case format
    when "html"
      "<a href=\"#{url}\">#{url}</a>"
    else
      url
    end
  end

  def self.write(str = "", format = $format)
    str = "" if str.nil?

    if format == "html"
      str = "  " + str + "<br>"
    end

    puts str.encode('utf-8')
  end
end