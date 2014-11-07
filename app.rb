#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'uri'
require 'data_mapper'
require 'omniauth-oauth2'      
require 'omniauth-google-oauth2'
require 'pry'
require 'erubis'               
require 'pp'
require 'chartkick'
require 'xmlsimple'
require 'restclient'
require 'dm-timestamps'
require 'dm-core'
require 'dm-types'

#%w( dm-core dm-timestamps dm-types restclient xmlsimple).each  { |lib| require lib}


configure :development, :test do
  DataMapper.setup( :default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/my_shortened_urls.db" )
end


configure :production do #heroku
  DataMapper.setup(:default, ENV['DATABASE_URL'])
end

DataMapper::Logger.new($stdout, :debug)
DataMapper::Model.raise_on_save_failure = true 

require_relative 'model'

DataMapper.finalize

#DataMapper.auto_migrate!
DataMapper.auto_upgrade! # No borra información , actualiza.

#Variable global
Base = 36 
#$email = ""

#Control del OmniAuth
use OmniAuth::Builder do       
  config = YAML.load_file 'config/config.yml'
  provider :google_oauth2, config['identifier'], config['secret']
end
  
enable :sessions               
set :session_secret, '*&(^#234a)'




get '/' do
	puts "inside get '/': #{params}"
	session[:email] = " "
	@list = ShortenedUrl.all(:order => [ :id.asc ], :limit => 20, :usuario => " ")  #listar url generales,las que no estan identificadas         
	#haml :index
        puts ""
        #puts "IP de la peticion #{request.ip}"
        puts "IP de la peticion #{env['REMOTE_ADDR']}"
        puts get_remote_ip(env)
        puts ""
        haml :index
end




get '/auth/:name/callback' do
        session[:auth] = @auth = request.env['omniauth.auth']
	session[:name] = @auth['info'].first_name + " " + @auth['info'].last_name
	session[:email] = @auth['info'].email
        if session[:auth] then  #@auth
        begin
	        puts ""
                puts "IP de la peticion #{request.ip}"
                puts ""
                puts "inside get '/': #{params}"
                puts "inside get '/': #{params}"
                @list = ShortenedUrl.all(:order => [ :id.asc ], :limit => 20, :usuario => session[:email])   #listar url del usuario  
                haml :index
        end
        else
                redirect '/exit'
        end

end



get '/exit' do
  session.clear
  $email = ""
  redirect '/'
end


post '/' do
  uri = URI::parse(params[:url])
  if uri.is_a? URI::HTTP or uri.is_a? URI::HTTPS then
    begin
      if params[:url_opc] == ""
        @short_url = ShortenedUrl.first_or_create(:url => params[:url], :url_opc => params[:url_opc], :usuario => session[:email], :n_visits => 0)
      else
        @short_url_opc = ShortenedUrl.first_or_create(:url => params[:url], :url_opc => params[:url_opc], :usuario => session[:email], :n_visits => 0)
      end
    rescue Exception => e
      puts "EXCEPTION!"
      pp @short_url
      puts e.message
    end
  else
    logger.info "Error! <#{params[:url]}> is not a valid URL"
  end
  redirect '/'
end



=begin
get '/estadisticas/:id' do
  
  haml :estadisticas, :layout => false

end
=end
get '/est' do
        if session[:auth]
                @list = ShortenedUrl.all(:order => [ :n_visits.desc ], :limit => 20, :usuario=> session[:email])   #listar url del usuario            
        else
                @list = ShortenedUrl.all(:order => [ :id.asc ], :limit => 20, :usuario => " ")  #listar url generales,las que no estan identificada    s
        end
        haml :est
end

get '/grafics/:shortened' do

	@country = Hash.new
	@ciudad  = Hash.new	
	
	p "parametro estadistica"
	p params[:shortened]
	url = ShortenedUrl.first(:id => params[:shortened].to_i(Base)) 
	@list = ShortenedUrl.first(:url_opc => url.url_opc)  #para sacar los datos del url corto
	p "URL que coge"
	p url
	

	visit = Visit.all(:shortened_url => url)  #datos guardados en tabla visit de ese url corto
        
	#guardamos en el hash las veces que aparece ese pais,ciudad

	visit.each { |visit|
        	if(@country[visit.country].nil? == true)
			@country[visit.country] = 1
		else
			@country[visit.country] +=1
		end
		
		if(@ciudad[visit.city].nil? == true)
			@ciudad[visit.city] = 1
		else
			@ciudad[visit.city] +=1
		end
	}

	haml :grafics, :layout => false
end

get '/:shortened' do
  puts "inside get '/:shortened': #{params}"
  puts "Los parametros son: #{params[:shortened]}"
    short_url = ShortenedUrl.first(:id => params[:shortened].to_i(Base))
    short_url_opc = ShortenedUrl.first(:url_opc => params[:shortened])
    
  if short_url_opc
	short_url_opc.n_visits += 1  #incrementamos una visita
  	short_url_opc.save
	data = get_geo
	visit = Visit.new(:ip => data['ip'], :country => data['countryName'], :countryCode => data['countryCode'], :city => data["city"],:latitud => data["latitude"], :longitud => data["longitude"], :shortened_url => short_url_opc, :created_at => Time.now)
	visit.save
        redirect short_url_opc.url, 301
=begin
  else
	short_url.n_visits += 1  #incrementamos una visita
	short_url.save
	data = get_geo
	visit = Visit.new(:ip => data['ip'], :country => data['countryName'], :countryCode => data['countryCode'], :city => data["city"],:latitud => data["latitude"], :longitud => data["longitude"], :shortened_url => short_url, :created_at => Time.now)	
	visit.save
        redirect short_url.url, 301
  end
=end
  end	
end


def get_geo
    xml = RestClient.get "http://ip.pycox.com/xml/#{get_remote_ip(env)}"
    data = XmlSimple.xml_in(xml.to_s)
     {"ip" => data['q'][0].to_s, "countryCode" => data['country_code3'][0].to_s, "countryName" => data['country_name'][0].to_s, "city" => data['city'][0].to_s, "latitude" => data['latitude'][0].to_s, "longitude" => data['longitude'][0].to_s}
end


def get_remote_ip(env)
  puts "request.url = #{request.url}"
  puts "request.ip = #{request.ip}"
  if addr = env['HTTP_X_FORWARDED_FOR']
    puts "env['HTTP_X_FORWARDED_FOR'] = #{addr}"
    addr.split(',').first.strip
  else
    puts "env['REMOTE_ADDR'] = #{env['REMOTE_ADDR']}"
    env['REMOTE_ADDR']
  end
end  
error do haml :index end