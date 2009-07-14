# PubSubHubBub subscribers check - check the topic and secret and
# return hub.challenge or channel name for superfeedr
get '/hub/callback/:id' do
  channel = DB[:channels].filter(:name => params[:id]).first
  throw :halt, [404, "Not found"]  unless channel
  return channel[:name] if channel[:type] == 'superfeedr'
  url = [params['hub.topic']].pack("m*").strip
  unless request['hub.verify_token'] == channel[:secret] and url == channel[:topic]
    throw :halt, [404, "Not found"]
  end
  request['hub.challenge']
end  

post '/hub/callback/:id' do
  channel = DB[:channels].filter(:name => params[:id]).first
  throw :halt, [404, "Not found"] unless channel
  postman(channel[:id], atom_parse(request.body.string)).to_json
end 
