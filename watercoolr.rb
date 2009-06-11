require 'rubygems'
require 'sinatra'
require 'sequel'
require 'zlib'
require 'json'

begin
  require 'httpclient'
  MyClient = HTTPClient
rescue
  require 'rest_client'
  MyClient = RestClient
end    


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
      # TODO: channel types: 'seq' - sequential, 'par' - parallel
      # defining how the messages will be send to the subscribers
      varchar :type, :size => 32, :default => 'seq'
    end
    DB.add_index :channels, [:name], :unique => true
  end

  unless DB.table_exists? "subscribers"
    DB.create_table :subscribers do
      primary_key :id
      foreign_key :channel_id
      varchar :url, :size => 128
      # TODO: sybs types - 'github', 'messagepub' etc.
      # defining how the messages will be formatted
      varchar :type, :size => 32, :default => 'github'
    end
    DB.add_index :subscribers, [:channel_id, :url], :unique => true
  end
end

helpers do
  def gen_id
    base = rand(100000000).to_s
    salt = Time.now.to_s
    Zlib.crc32(base + salt).to_s(36)
  end

  # post a message to a list of subscribers (urls)
  def postman(subs, msg)
    return { :status => 'FAIL' } unless (subs and msg)
    ok = not_ok = slow = 0
    subs.each do |sub|
      begin
        MyTimer.timeout(5) do
          MyClient.post(sub, :data => msg)
          ok += 1
        end  
      rescue Timeout::Error
        slow += 1
      rescue
        not_ok += 1
      end
    end
    # get with hash[:status][:ok] etc.
    return {:status => {:ok => ok, :fail => not_ok, :timeout => slow}}
  end  
end



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
  DB[:channels] << { :name => id, :type => type }
  { :id => id.to_s }.to_json
end

post '/sub' do
  begin
    data = JSON.parse(params[:data])
    raise unless url = data['url']
    channel_name = data['channel'] || 'boo'
    type = data['type'] || 'github'
    rec = DB[:channels].filter(:name => channel_name).first
    raise unless rec[:id]  
    unless DB[:subscribers].filter(:channel_id => rec[:id], :url => url).first
      raise unless DB[:subscribers] << { :channel_id => rec[:id], :url => url, :type => type }
    end
    {:status => 'OK'}.to_json
  rescue
    {:status => 'FAIL'}.to_json
  end  
end

post '/pub' do
  begin
    data = JSON.parse(params[:data])
    channel_name = data['channel'] || 'boo'
    message = data['message']
    rec = DB[:channels].filter(:name => channel_name).first
    raise unless rec[:id]  
    subs = DB[:subscribers].filter(:channel_id => rec[:id]).to_a.collect { |s| s[:url] }
    raise unless subs
    postman(subs, message).to_json
  rescue
    {:status => 'FAIL'}.to_json
  end  
end
