hook :twitter do |data,payload|
  cl = HTTPClient.new
  cl.set_auth("http://twitter.com/", data['username'], data['password'])
  status = {:status => payload['message'], :source => 'watercoolr'}
  response = cl.post("http://twitter.com/statuses/update.xml", status)
end  
