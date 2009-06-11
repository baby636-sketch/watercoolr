require 'rubygems'
require 'sinatra'


post '/slow-handler' do
  sleep(10)
  puts params[:data].inspect
end

post '/test-handler' do
  puts params[:data].inspect
end
