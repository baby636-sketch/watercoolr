require 'rubygems'
require 'sinatra'


post '/slow-handler' do
  sleep(10)
  params[:data].inspect
end

post '/test-handler' do
  params[:data].inspect
end
