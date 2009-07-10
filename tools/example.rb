require 'rubygems'
require 'rest_client'
require 'json'

puts "creating channel..."
resp = RestClient.post 'http://admin:change_me@localhost:4567/channels', :data => ''
id = JSON.parse(resp)["id"]

puts "adding subscribers to channel #{id}"
resp = RestClient.post 'http://localhost:4567/subscribe', :data => { :channel => id, :url => 'http://localhost:8080/test-handler' }.to_json
puts resp

resp = RestClient.post 'http://localhost:4567/subscribe', :data => { :channel => id, :url => 'http://localhost:8080/slow-handler' }.to_json
puts resp

puts "posting message to #{id}"
resp = RestClient.post 'http://localhost:4567/publish', :payload => { :channel => id, :message => 'HAYYYY' }.to_json
puts resp

# protected channels
puts "creating protected channel..."
resp = RestClient.post 'http://admin:change_me@localhost:4567/channels', :data => {:secret => 'secret123'}.to_json
id = JSON.parse(resp)["id"]

# will fail
puts "adding subscribers to channel #{id}"
resp = RestClient.post 'http://localhost:4567/subscribe', :data => { :channel => id, :url => 'http://localhost:8080/test-handler' }.to_json
puts resp

# will success
puts "adding subscribers to protected channel #{id}"
resp = RestClient.post 'http://localhost:4567/subscribe', :data => { :channel => id, :url => 'http://localhost:8080/test-handler', :secret => 'secret123' }.to_json
puts resp
