def hash2text(hash)
  text = ""
  text = hash if hash.kind_of?(String)
  hash.each { |k,v| text << "#{k} = #{v}\n" } if hash.kind_of?(Hash)
  text  
end 

def payload2text(payload)
  return hash2text(payload) unless payload.kind_of?(Array)
  text = ""
  payload.each { |a| text << hash2text(a)+"\n" }
  text
end  

# Jabber::Simple does some insane kind of queueing if it thinks
# we are not in their buddy list (which is always) so messages
# never get sent before we disconnect. This forces the library
# to assume the recipient is a buddy.
class Jabber::Simple
  def subscribed_to?(x); true; end
  end

# to: data['to'], 
# from: data['user'], data['password']
# message: payload['message']
hook :xmpp do |data,payload|
  message  = payload2text(payload['message'])
  raise "[E] No valid recipient: data['to']" unless data['to']
  im = Jabber::Simple.new(data['username'], data['password'])
  # Ask recipient to be our buddy if need be
  im.add(data['to'])
  # Accept any friend request
  im.accept_subscriptions = true
  im.deliver(data['to'], message)
  im.disconnect
end  
