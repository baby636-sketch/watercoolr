# see: http://messagepub.com/documentation/api
require 'messagepub'

class MPubClient
  include MessagePub
  def self.post(apikey, msg, data)
    client = Client.new(apikey)
    n = Notification.new(:body => msg, :escalation => data['escalation'])
    data['recipients']['recipient'].each { |r|
      n.add_recipient(
        Recipient.new(:position => r['position'], 
                      :channel => r['channel'], 
                      :address => r['address'])
      )
    }  
    client.create!(n)
  end  
end
