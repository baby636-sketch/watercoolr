hook :prowl do |data, payload|
  cl = HTTPClient.new
  cl.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
  prl_params = {:apikey => data['apikey'], 
                :priority => data['priority'] ? data['priority'] : 0,
                :event => 'watercoolri alert',
                :description => payload['message'],
                :application => 'watercoolr'}
  prl_params[:event] = payload['title'] if payload['title']
  response = cl.post('https://prowl.weks.net/publicapi/add', prl_params)
end  
