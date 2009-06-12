require 'rubygems'
require 'httpclient'
require 'json'
require 'activesupport'

#puts "creating channel..."
#resp = RestClient.post 'http://localhost:4567/channels', :data => ''
#id = JSON.parse(resp)["id"]

#puts "adding subscribers to channel #{id}"

d = "<notification><body>You have a message waiting for you in your inbox</body><escalation>30</escalation><recipients><recipient><position>1</position><channel>email</channel><address>stoyan@i.softbank.jp</address></recipient></recipients></notification>"

mp = { :recipient => [
  {:position => 1, :channel => 'email', :address => 'stoyan@i.softbank.jp'}
]}

#resp = RestClient.post 'http://localhost:4567/sub', 
#  :data => { :channel => id, :url => 'http://356ca07356acc16995b206adb012b708ef3f2cab@messagepub.com/notifications.xml', 
#             :type => 'messagepub', :escalation => 30,
#             :recipients => mp }.to_json

hsh = { :body => 'PubSub to MessagePub',
        :escalation => 30,
        :recipients => mp }
r = HTTPClient.post('http://356ca07356acc16995b206adb012b708ef3f2cab@messagepub.com/notifications.xml',
  hsh.to_xml(
        :root => "notification", 
        :skip_types => true 
        ))
puts r.inspect

#puts "posting message to #{id}"
#resp = RestClient.post 'http://localhost:4567/pub', 
#  :data => { :channel => id, 
#             :message => 'PubSub to MessagePub' }.to_json
#puts resp
