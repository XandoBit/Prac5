class ShortenedUrl
  include DataMapper::Resource
 
   property :id, Serial
   property :url, Text
   property :url_opc, Text
   property :usuario, Text
   property :email, Text
   property :created_at, DataTime
   property :n_visits
 
   has n, :visits
end


class Visit
  include DataMapper::Resource

  property  :id,          Serial
  property  :ip,          IPAddress
  property  :created_at,  DateTime
  property  :country,     String
  #belongs_to  :link

  belongs_to  :shortened_url

  before :create, :set_country
end


  def set_country
    xml = RestClient.get "http://api.hostip.info/get_xml.php?ip=#{ip}"
    self.country = XmlSimple.xml_in(xml.to_s, { 'ForceArray' => false })['CountryName'].to_s
    self.save
  end
#end
