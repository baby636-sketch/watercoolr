require 'rubygems'
require 'httpclient'
require 'json'

puts "creating channel..."
resp = HTTPClient.post('http://localhost:4567/channels', :data => { :type => 'pingfm'}.to_json)
id = JSON.parse(resp.content)["id"]

puts "adding subscribers to channel #{id}"
resp = HTTPClient.post('http://localhost:4567/sub', :data => { :channel => id, :url => 'http://www.postbin.org/suxo6u' }.to_json)
puts resp.content

puts "posting message to #{id}"
resp = HTTPClient.post('http://localhost:4567/pub/pingfm', 
       :method => 'status',
       :message => "http://ping.fm/p/OoIr3 - Let's try also some attachement",
       :media => "http://p.ping.fm/img/FwlinJx0/38a7f281b6ca981a.jpg",
       :raw_message => "Let's try also some attachement",
       :location => 'Home'       
       )
puts resp.content
