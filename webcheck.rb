require 'awesome_print'
require 'httpclient'
require 'mail'
require 'yaml'

DEFAULT_MUA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 5_0_1 like Mac OS X) AppleWebKit/534.46 (KHTML, like Gecko) Mobile/9A405'

settings = YAML.load_file("settings.yaml") rescue {}
#ap settings

mua = settings['mua'] || DEFAULT_MUA
cli = HTTPClient.new(:agent_name => mua)

unless settings.has_key?('user') && settings.has_key?('pass')
  raise 'settings.yaml needs user and pass fields for email'
end

Mail.defaults do
  delivery_method :smtp, {
    :address => 'smtp.gmail.com',
    :port => '587',
    :user_name => settings['user'],
    :password => settings['pass'],
    :authentication => :plain,
    :enable_starttls_auto => true,
  }
end

urls = settings['urls']

loop do

  results = urls.map do |url|
    puts "Fetching #{url}"
    msg = cli.get(url)
    content = msg.http_body.content
    [
      url,
      {
       :headers => msg.headers,
       :size => content.length,
       :digest => Digest::MD5.hexdigest(content),
      }
    ]
  end

  # splat the results back into a hash
  results = Hash[*results.flatten]
  #ap results

  previous = YAML.load_file("results.yaml") rescue {}

  File.open('results.yaml', 'w') do |f|
    f.write(results.to_yaml)
  end

  previous.each do |url, hash|

    if results.has_key? url
      was = hash[:digest]
      now = results[url][:digest]

      if now != was
        mail = Mail.new
        mail[:from] = settings['user']
        mail[:to] = settings['user']
        mail[:subject] = 'Change detected!'
        mail[:body] = <<-END
        Web page change detected!

        #{url} changed.

        Previous digest: #{was}
        New digest: #{now}

        Go get em!
        END

        puts mail
        mail.deliver!
      end
    end
  end

  puts 'ZZZzzzZZzzz...'
  sleep(2 * 60 * 60) # seconds

end
