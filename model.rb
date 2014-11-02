class ShortenedUrl
  include DataMapper::Resource
 
   property :id, Serial
   property :url, Text
   property :url_opc, Text
   property :usuario, Text
 
end

class ShortenedUrl
  include DataMapper::Resource

  property :id, Serial
  property :short, Text
  property :url, Text

  has n, :visits
end

