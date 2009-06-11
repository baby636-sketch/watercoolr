# ping.fm publisher 
# see: http://groups.google.com/group/pingfm-developers/web/working-with-a-custom-url
# need a channel, type 'pingfm' 
post '/pub/pingfm' do
  begin
    rec = DB[:channels].filter(:type => 'pingfm').order(:created).last
    raise unless rec[:id]
    msg = {}
    msg[:method] = params[:method]
    if params[:media]
      msg[:media] = params[:media]
      msg[:text] = params[:raw_message]
    else
      msg[:text] = params[:message]  
    end  
    msg[:title] = (params[:method] == 'blog') ? params[:title] : msg[:text]
    msg[:location] = params[:location] if params[:location]
    postman(rec[:id], msg.to_json).to_json
  rescue Exception => e
    {:status => e.to_s}.to_json
  end  
end

post '/pub/github' do
  begin
    rec = DB[:channels].filter(:type => 'pingfm').order(:created).last
    raise unless rec[:id]
    postman(rec[:id], params[:payload]).to_json
  rescue Exception => e
    {:status => e.to_s}.to_json
  end  
end  
