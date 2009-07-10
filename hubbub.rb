helpers do
  # verify subscribers callback
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
    status 400
    return "400 Bad request: Expected 'hub.mode=publish' and 'hub.url'"
  end 
  if params['hub.url'] == ""
    status 400
    return "400 Bad request: Empty 'hub.url' parameter"
  end
  begin 
    id = [params['hub.url']].pack("m*").strip
    topic = DB[:channels].filter(:name => id)
    if topic.first
      topic.update(:updated => Time.now)
    else  
      DB[:channels] << { :name => id, :created => Time.now, :type => 'pubsubhubbub' }
    end  
  rescue Exception => e
    puts e.to_s
    status 404
    return "404 Not Found"
  end  
  status 204
  return "204 No Content"
end

# PubSubHubBub subscribers check - check the topic and secret and
# return hub.challenge
get '/hub/callback' do
  id = [params['hub.topic']].pack("m*").strip
  topic = DB[:channels].filter(:name => id)
  respond "404 Not Found", 404  unless topic.first
  if request.post?
    postman(id, atom_parse(request.body.string)).to_json
    {:status => 'OK'}.to_json
  else
    rec_all = DB[:users].filter(:name => 'all', :service => 'channels').first
    respond "404 Not Found", 404 unless rec_all
    # secret per channel
    rec = DB[:users].filter(:name => "#{id}", :service => 'channels').first
    rec = rec_all unless rec
    respond "404 Not Found", 404 unless request['hub.verify_token'] == rec[:password]
    request['hub.challenge']
  end  
end 

get '/hub/verify' do
  topic, secret = params[:topic], params[:secret]
  unless topic and secret
    status 400
    return "400 Bad request: need url and secret parameters"
  end
  data = { :mode => 'subscribe', :verify => 'sync', :vtoken => secret, :url => topic }
  unless do_verify("http://localhost:4567/hub/callback", data)
    status 409
    return "409 Subscription verification failed"
  end
  status 204
  "204 No Content"
end  

# Check ownership - response body is the superfeedr secret token
get '/superfeedr' do
  begin
    rec = DB[:channels].filter(:type => 'superfeedr').order(:created).last
    raise "'superfeedr' type topic does not exists" unless rec[:id]
    rec[:name]
  rescue Exception => e  
    {:status => e.to_s}.to_json
  end  
end  

post '/superfeedr' do
  begin
    rec = DB[:channels].filter(:type => 'superfeedr').order(:created).last
    raise "'superfeedr' type topic does not exists" unless rec[:id]
    postman(rec[:id], atom_parse(request.body.string)).to_json
    {:status => 'OK'}.to_json
  rescue Exception => e
    status 500
    {:status => e.to_s}.to_json
  end  
end
