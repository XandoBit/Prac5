class ShortenedUrl
  include DataMapper::Resource
 
   property :id, Serial
   property :url, Text
   property :url_opc, Text
   property :usuario, Text
 
end

