require 'dm-core'
require 'dm-migrations'
require 'restclient'
require 'xmlsimple'
require 'dm-timestamps'

class ShortenedUrl
  include DataMapper::Resource
 
   property :id, Serial
   property :url, Text
   property :url_opc, Text
   property :usuario, Text
   property :email, Text
   property :created_at, DateTime
   property :n_visits, Integer
 
   has n, :visits
end


class Visit
  include DataMapper::Resource

  property  :id,          Serial
  property  :ip,          IPAddress
  property  :created_at,  DateTime
  property  :country,     String
  property :countryCode, String
  property :city, String
  property :latitud, String
  property :longitud, String

  
  belongs_to  :shortened_url
  
end

=begin
  before :create, :set_country
  
    def set_country
    xml = RestClient.get "http://api.hostip.info/get_xml.php?ip=#{ip}"
    self.country = XmlSimple.xml_in(xml.to_s, { 'ForceArray' => false })['CountryName'].to_s
    self.save
  end
end

#end

=end
