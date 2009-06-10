require 'rubygems'
require 'rest_client'
require 'json'

puts "creating channel..."
resp = RestClient.post 'http://localhost:4567/channels', :data => ''
id = JSON.parse(resp)["id"]

puts "adding subscribers to channel #{id}"
resp = RestClient.post 'http://localhost:4567/subscribers', :data => { :channel => id, :url => 'http://localhost:8080/test-handler' }.to_json
puts resp
resp = RestClient.post 'http://localhost:4567/subscribers', :data => { :channel => id, :url => 'http://localhost:8080/slow-handler' }.to_json
puts resp

puts "posting message to #{id}"
resp = RestClient.post 'http://localhost:4567/messages', :data => { :channel => id, :message => 'HAYYYY' }.to_json
puts resp
