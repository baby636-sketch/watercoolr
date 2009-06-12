require 'rubygems'
require 'rest_client'
require 'json'

puts "creating channel..."
resp = RestClient.post('http://localhost:4567/channels', :data => '')
id = JSON.parse(resp)["id"]

puts "adding subscribers to channel #{id}"

mp = { :recipient => [
  {:position => 1, :channel => 'email', :address => 'stoyan@i.softbank.jp'},
  {:position => 2, :channel => 'twitter', :address => 'zh'}
]}

resp = RestClient.post('http://localhost:4567/sub', 
  :data => { :channel => id, :type => 'messagepub', 
             :url => '356ca07356acc16995b206adb012b708ef3f2cab',
             :escalation => 30, :recipients => mp }.to_json)
puts resp

puts "posting message to #{id}"
resp = RestClient.post('http://localhost:4567/pub', 
  :data => { :channel => id, 
             :message => 'PubSub to MessagePub' }.to_json)
puts resp
