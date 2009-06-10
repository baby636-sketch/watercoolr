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
    end
  end

  unless DB.table_exists? "subscribers"
    DB.create_table :subscribers do
      primary_key :id
      foreign_key :channel_id
      varchar :url, :size => 128
    end
  end
end

helpers do
  def gen_id
    base = rand(100000000).to_s
    salt = Time.now.to_s
    Zlib.crc32(base + salt).to_s(36)
  end
end



get '/' do
  erb :index
end

post '/channels' do
  id = gen_id
  DB[:channels] << { :name => id }
  { :id => id.to_s }.to_json
end

post '/subscribers' do
  res = false
  data = JSON.parse(params[:data])
  channel_name = data['channel'] || 'boo'
  url = data['url'] || nil
  if rec = DB[:channels].filter(:name => channel_name).first
    if url and rec[:id]
      unless DB[:subscribers].filter(:channel_id => rec[:id], :url => url).first
        res = DB[:subscribers] << { :channel_id => rec[:id], :url => url }
      end
    end
  end
  if res
    { :status => 'OK' }.to_json
  else
    { :status => 'FAIL' }.to_json
  end
end

post '/messages' do
  ok = not_ok = slow = 0
  data = JSON.parse(params[:data])
  channel_name = data['channel'] || 'boo'
  message = data['message'] || nil
  if rec = DB[:channels].filter(:name => channel_name).first
    if message and rec[:id]
      subs = DB[:subscribers].filter(:channel_id => rec[:id]).to_a
      if subs
        subs.each do |sub|
          begin
            MyTimer.timeout(5) do
              MyClient.post(sub[:url], :data => message)
              ok += 1
            end  
          rescue Timeout::Error
            slow += 1
          rescue
            not_ok += 1
          end
        end
      end
    end
  end
  { :ok => ok, :fail => not_ok, :timeout => slow }.to_json
end
