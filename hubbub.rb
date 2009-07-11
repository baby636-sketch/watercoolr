helpers do
  # verify subscribers callback
  # TODO: use it in /hub/subscribe
  def do_verify(url, data)
    return false unless url and data
    begin
      challenge = gen_id
      query = { 'hub.mode' => data[:mode], 
                'hub.topic' => data[:url],
                'hub.challenge' => challenge,
                'hub.verify_token' => data[:vtoken]}
      MyTimer.timeout(5) do
         res = HTTPClient.get_content(url, query)
         return false unless res and res == challenge
      end
    rescue
      return false
    end  
    return true
  end
end

# Publishers registering new topics here
get '/hub/publish' do
  erb :publish
end

# Publishers pinging this URL, when there is new content
post '/hub/publish' do
  unless params['hub.mode'] and params['hub.url'] and params['hub.mode'] == 'publish'
    throw :halt, [400, "Bad request: Expected 'hub.mode=publish' and 'hub.url'"]
  end 
  throw :halt, [400, "Bad request: Empty 'hub.url' parameter"] if params['hub.url'] == ""
  begin 
    url = [params['hub.url']].pack("m*").strip
    channel = DB[:channels].filter(:topic => url)
    if channel.first
      channel.update(:updated => Time.now)
      id = channel.first[:id]
    else  
      id = gen_id
      DB[:channels] << { :name => id, :topic => url, :created => Time.now, 
                         :type => 'pubsubhubbub', :secret => 'change_me' }
    end 
    { :id => id.to_s }.to_json 
  rescue Exception => e
    throw :halt, [404, e.to_s]
  end  
  status 204
  return "204 No Content"
end

# PubSubHubBub subscribers check - check the topic and secret and
# return hub.challenge
get '/hub/callback/:id' do
  channel = DB[:channels].filter(:name => params[:id]).first
  throw :halt, [404, "Not found"]  unless channel
  url = [params['hub.topic']].pack("m*").strip
  unless request['hub.verify_token'] == channel[:secret] and url == channel[:topic]
    throw :halt, [404, "Not found"]
  end
  request['hub.challenge']
end  

post '/hub/callback/:id' do
  channel = DB[:channels].filter(:name => params[:id]).first
  throw :halt, [404, "Not found"] unless channel
  postman(channel[:id], request.body.string).to_json
  {:status => 'OK'}.to_json
end 


# Check ownership - response body is the superfeedr secret token
get '/superfeedr' do
  rec = DB[:channels].filter(:type => 'superfeedr').order(:created).last
  throw :halt, [404, "Not found"] unless rec
  rec[:name]
end  

post '/superfeedr' do
  begin
    rec = DB[:channels].filter(:type => 'superfeedr').order(:created).last
    throw :halt, [404, "'superfeedr' type topic does not exists"] unless rec[:id]
    postman(rec[:id], atom_parse(request.body.string)).to_json
    {:status => 'OK'}.to_json
  rescue Exception => e
    throw :halt, [500, {:status => e.to_s}.to_json]
  end  
end
