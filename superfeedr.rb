# superfeedr hooks - needs 'authentication' before usage
# first register topic with ID=superfeedr token
require 'crack'

# Check ownership - response body is the superfeedr secret token
get '/superfeedr' do
  begin
    rec = DB[:channels].filter(:type => 'superfeedr').order(:created).last
    raise "'superfeedr' type topic does not exists" unless rec[:id]
    rec[:name]
  rescue Exception => e  
    {:status => e.to_s}.to_json
  end  
end  

post '/superfeedr' do
  begin
    rec = DB[:channels].filter(:type => 'superfeedr').order(:created).last
    raise "'superfeedr' type topic does not exists" unless rec[:id]
    atom = Crack::XML.parse(request.body.string)
    r = []
    if atom["feed"]["entry"].kind_of?(Array)
      atom["feed"]["entry"].each { |e| 
        r << {:id => e["id"], :title => e["title"], :published => e["published"] }
      }
    else
      e = atom["feed"]["entry"]
      r = {:id => e["id"], :title => e["title"], :published => e["published"] }
    end
    postman(rec[:id], r).to_json
    {:status => 'OK'}.to_json
  rescue Exception => e
    status 500
    {:status => e.to_s}.to_json
  end  
end
