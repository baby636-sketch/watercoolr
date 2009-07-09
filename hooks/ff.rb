hook :ff do |data, payload|
  cl = HTTPClient.new
  cl.set_auth('http://friendfeed.com/', data['username'], data['key'])
  ff_params = {:room => data['room'] ? data['room'] : 'hooks', :via => 'watercoolr'}
  if payload['title']
    ff_params[:title] = payload['title']
    ff_params[:comment] = payload['message']
  else
    ff_params[:title] = payload['message']
  end  
  response = cl.post('http://friendfeed.com/api/share', ff_params)
end  
