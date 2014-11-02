ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'rack/test'
require 'test/unit'
require_relative '../app.rb'

include Test::Unit::Assertions


include Rack::Test::Methods

def app
	Sinatra::Application
end

describe 'Tests de app.rb' do
     before :all do
        @Pagina = "http://www.marca.com"
	@Pagina2 = "http://www.as.com"
	@ShortUrl = "marca"
	@Objeto = ShortenedUrl.first_or_create(:url => "http://www.marca.com", :url_opc =>'periodico', :usuario => 'Rushil')
	@ObjetoDist = ShortenedUrl.first(:usuario => 'Rushil')
	
     end
     
     it "Debe devolver marca está en la base de datos" do
		assert_equal @Pagina, @Objeto.url 
    end

    it "Debe devolver que el usuario es igual" do
   		assert_equal 'Rushil', @Objeto.usuario
    end
    
    it "Debe devolver que no coincide el username de objeto con Pedro" do
   		assert_not_equal('Rus', @Objeto.usuario)
    end
end    