require 'xmpp4r'
require 'xmpp4r-simple'

def hook(name)
  # default secret token
  rec_all = DB[:users].filter(:name => 'all', :service => 'hooks').first
  raise "[E] No default hooks secret token - /hooks/#{name}/:SECRET/" unless rec_all
  # secret per hook
  rec = DB[:users].filter(:name => "#{name}", :service => 'hooks').first
  rec = rec_all unless rec
  MyTimer.timeout(10) do
    post "/hook/#{name}/#{rec[:password]}/" do
      raise "[E] No 'payload' parameted provided" unless params[:payload]
      payload = JSON.parse(params[:payload])
      data = params[:data] ? JSON.parse(params[:data]) : {}
      yield data, payload
    end  
  end
  rescue Timeout::Error
end  

Dir["#{File.dirname(__FILE__)}/hooks/**/*.rb"].each { |hook| load hook }
