# superfeedr hooks - needs 'authentication' before usage
# first register topic with ID=superfeedr token

post '/superfeedr/channels' do
  begin
    data = JSON.parse(params[:data])
    type = data['type'] || 'superfeedr'
    raise "No valid token provided" unless id = data['token']
  rescue Exception => e
    return { :id => nil, :status => e.to_s }.to_json 
  end 
  if ch = DB[:channels].filter(:name => id).first
    { :id => ch[:name].to_s }.to_json
  else 
    DB[:channels] << { :name => id, :created => Time.now, :type => type }
    { :id => id.to_s }.to_json
  end 
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
    postman(rec[:id], request.body).to_json
    {:status => 'OK'}.to_json
  rescue Exception => e
    status 500
    {:status => e.to_s}.to_json
  end  
end
