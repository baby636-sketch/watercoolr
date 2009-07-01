require 'rubygems'
require 'sinatra'
require 'sequel'
require 'zlib'
require 'json'
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
      time    :created
      index   [:created]
      index   [:name], :unique => true
    end
    # system channels
    DB[:channels] << { :name => '__pingfm__', :created => Time.now, :type => 'pingfm' }
    DB[:channels] << { :name => '__github__', :created => Time.now, :type => 'github' }
  end

  unless DB.table_exists? "subscribers"
    DB.create_table :subscribers do
      primary_key :id
      foreign_key :channel_id
      varchar     :url, :size => 128
      # TODO: subs types - 'github', 'messagepub' etc.
      # defining how the messages will be formatted
      varchar     :type, :size => 32, :default => 'github'
      text        :data 
      index       [:channel_id, :url], :unique => true
    end
  end
end

helpers do
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

  # post a message to a list of subscribers (urls)
  def postman(channel, msg)
    subs = DB[:subscribers].filter(:channel_id => channel).to_a
    return { :status => 'FAIL' } unless (subs and msg)
    subs.each do |sub|
      begin
        raise "No valid URL provided" unless sub[:url]
        MyTimer.timeout(5) do
        # see: http://messagepub.com/documentation/api
          if sub[:type] == 'messagepub'
            MPubClient.post(sub[:url], msg, unmarshal(sub[:data]))
          else
            HTTPClient.post(sub[:url], :payload => msg)
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
load 'superfeedr.rb'

get '/' do
  erb :index
end

post '/channels' do
  id = gen_id
  # second chance
  id = gen_id if DB[:channels].filter(:name => id).first
  begin
    data = JSON.parse(params[:data])
    type = data['type'] || 'seq'
  rescue
    type = 'seq'
  end  
  DB[:channels] << { :name => id, :created => Time.now, :type => type }
  { :id => id.to_s }.to_json
end

post '/subscribe' do
  begin
    data = JSON.parse(params[:data])
    raise "missing URL in the 'data' parameter" unless url = data['url']
    channel_name = data['channel'] || 'boo'
    type = data['type'] || 'github'
    ['url', 'channel', 'type'].each { |d| data.delete(d) }
    rec = DB[:channels].filter(:name => channel_name).first
    raise "channel #{channel_name} does not exists" unless rec[:id]  
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
    data = JSON.parse(params[:data])
    channel_name = data['channel'] || 'boo'
    message = data['message']
    rec = DB[:channels].filter(:name => channel_name).first
    raise "channel #{channel_name} does not exists" unless rec[:id]  
    postman(rec[:id], message).to_json
  rescue Exception => e
    {:status => e.to_s}.to_json
  end  
end
