require 'rubygems'
require 'sinatra'
require 'sequel'
require 'zlib'
require 'json'
require 'crack'
require 'httpclient'

begin
  require 'system_timer'
  MyTimer = SystemTimer
rescue
  require 'timeout'
  MyTimer = Timeout
end

configure do
  DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://watercoolr.db')
  unless DB.table_exists? "channels"
    DB.create_table :channels do
      primary_key :id
      varchar :name, :size => 32
      # channel types: 'github', 'pingfm', 'superfeedr' etc.
      varchar :type, :size => 32, :default => 'seq'
      # pubsubhubbub support
      varchar :topic, :size => 128
      # protected channels
      varchar :secret, :size => 32
      time    :created
      time    :updated
      index   [:updated]
      index   [:topic]
      index   [:name], :unique => true
    end
    # system channels
    DB[:channels] << { :name => '__pingfm__', :created => Time.now, 
                       :type => 'pingfm', :secret => 'change_me' }
    DB[:channels] << { :name => '__github__', :created => Time.now, 
                       :type => 'github', :secret => 'change_me' }
  end

  unless DB.table_exists? "subscribers"
    DB.create_table :subscribers do
      primary_key :id
      foreign_key :channel_id
      varchar     :url, :size => 128
      varchar     :type, :size => 32, :default => 'github'
      integer     :state, :default => 0  # 0 - verified, 1 - need verification
      text        :data 
      index       [:channel_id, :url], :unique => true
    end
  end

  unless DB.table_exists? "users"
    DB.create_table :users do
      primary_key :id
      varchar :name, :size => 32
      varchar :password, :size => 32
      varchar :service, :size => 32
      index   [:name, :service], :unique => true
    end
    # Need to have at least admin user
    DB[:users] << { :name => 'admin', :password => 'change_me', :service => 'self' }
    # All hooks library URLs will be /hook/:name/:secret/
    # default secret
    DB[:users] << { :name => 'all', :password => 'change_me', :service => 'hooks' }
    # secret per hook
    # DB[:users] << { :name => 'ff', :password => 'change_me_too', :service => 'hooks' }
  end 
end

helpers do
  def protected!
    response['WWW-Authenticate'] = %(Basic realm="HTTP Auth") and \
    throw(:halt, [401, "Not authorized\n"]) and return unless authorized?
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    return false unless @auth.provided? && @auth.basic? && @auth.credentials
    user,pass = @auth.credentials
    return false unless DB[:users].filter(:name => user, :service => 'self', :password => pass).first
    true
  end

  def gen_id
    base = rand(100000000).to_s
    salt = Time.now.to_s
    Zlib.crc32(base + salt).to_s(36)
  end

  def marshal(string)
    [Marshal.dump(string)].pack('m*').strip!
  end

  def unmarshal(str)
    Marshal.load(str.unpack("m")[0])
  end

  def atom_time(date)
    date.getgm.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def atom_parse(text)
    atom = Crack::XML.parse(text)
    r = []
    if atom["feed"]["entry"].kind_of?(Array)
      atom["feed"]["entry"].each { |e| 
        r << {:id => e["id"], :title => e["title"], :published => e["published"] }
      }
    else
      e = atom["feed"]["entry"]
      r = {:id => e["id"], :title => e["title"], :published => e["published"] }
    end
    r
  end

  # post a message to a list of subscribers (urls)
  def postman(channel, msg)
    subs = DB[:subscribers].filter(:channel_id => channel).to_a
    return { :status => 'FAIL' } unless (subs and msg)
    subs.each do |sub|
      begin
        raise "No valid URL provided" unless sub[:url]
        # remove sensitive data for the 'debug' subscribers
        data = (sub[:type] == 'debug') ? {} : unmarshal(sub[:data])
        MyTimer.timeout(5) do
        # see: http://messagepub.com/documentation/api
          if sub[:type] == 'messagepub'
            MPubClient.post(sub[:url], msg, data)
          else
            HTTPClient.post(sub[:url], 
                            :payload => {:message => msg}.to_json,
                            :data => data.to_json)
          end
        end
      rescue Exception => e
        case e
          when Timeout::Error
            puts "Timeout: #{sub[:url]}"
          else  
            puts e.to_s
        end  
        next
      end
    end
    return {:status => 'OK'}
  end
end

# support for specific publisher and subscribers
# comment following lines if not needed
load 'pubs.rb'
load 'subs.rb'
load 'hubbub.rb'
load 'hooks.rb'

get '/' do
  erb :index
end

post '/channels' do
  protected!
  id = gen_id
  begin
    data = JSON.parse(params[:data])
    # superfeedr api key
    id = data['id'] if data['id'] && (data['type'] == 'superfeedr')
    if data['topic'] && (data['type'] == 'pubsubhubbub')
      topic = [data['topic']].pack("m*").strip
    else
      topic = nil
    end  
    type = data['type'] || 'seq'
    secret = data['secret']
  rescue Exception => e
    puts e.to_s
    type = 'seq'
  end
  unless DB[:channels].filter(:name => id).first
    DB[:channels] << { :name => id, :topic => topic, :created => Time.now, 
                       :type => type, :secret => secret }
  end  
  { :id => id.to_s }.to_json
end

post '/subscribe' do
  begin
    data = JSON.parse(params[:data])
    raise "missing URL in the 'data' parameter" unless url = data['url']
    channel_name = data['channel'] || 'boo'
    type = data['type'] || 'debug'
    ['url', 'channel', 'type'].each { |d| data.delete(d) }
    rec = DB[:channels].filter(:name => channel_name).first
    raise "channel #{channel_name} does not exists" unless rec[:id]
    if rec[:secret]
      raise "not authorized" unless rec[:secret] == data['secret']
      data.delete('secret')
    end  
    unless DB[:subscribers].filter(:channel_id => rec[:id], :url => url).first
      raise "DB insert failed" unless DB[:subscribers] << { 
                                            :channel_id => rec[:id], 
                                            :url => url, 
                                            :type => type,
                                            :data => marshal(data) }
    end
    {:status => 'OK'}.to_json
  rescue Exception => e
    {:status => e.to_s}.to_json
  end  
end

# general publisher - data contain both channel name and message
post '/publish' do
  begin
    data = JSON.parse(params[:payload])
    channel_name = data['channel'] || 'boo'
    message = data['message']
    rec = DB[:channels].filter(:name => channel_name).first
    raise "channel #{channel_name} does not exists" unless rec[:id]  
    postman(rec[:id], message).to_json
  rescue Exception => e
    {:status => e.to_s}.to_json
  end  
end
