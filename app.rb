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
	
	haml :grafics
end

get '/:shortened' do
  puts "inside get '/:shortened': #{params}"
  puts "Los parametros son: #{params[:shortened]}"
  #if (params[:shortened] == '' || params[:shortened].nil?)
    short_url = ShortenedUrl.first(:id => params[:shortened].to_i(Base))
    short_url_opc = ShortenedUrl.first(:url_opc => params[:shortened])
    
  if short_url_opc
	short_url_opc.n_visits += 1  #incrementamos una visita
  	short_url_opc.save
	data = get_geo
	visit = Visit.new(:ip => data['ip'], :country => data['countryName'], :countryCode => data['countryCode'], :city => data["city"],:latitud => data["latitude"], :longitud => data["longitude"], :shortened_url => short_url_opc, :created_at => Time.now)
	visit.save
        redirect short_url_opc.url, 301
  else
	short_url.n_visits += 1  #incrementamos una visita
	short_url.save
	data = get_geo
	visit = Visit.new(:ip => data['ip'], :country => data['countryName'], :countryCode => data['countryCode'], :city => data["city"],:latitud => data["latitude"], :longitud => data["longitude"], :shortened_url => short_url, :created_at => Time.now)	
	visit.save
        redirect short_url.url, 301
  end

end




=begin
get '/:shortened' do
  puts "inside get '/:shortened': #{params}"
  short_url = ShortenedUrl.first(:id => params[:shortened].to_i(Base))
  short_url_opc = ShortenedUrl.first(:url_opc => params[:shortened])

  # HTTP status codes that start with 3 (such as 301, 302) tell the
  # browser to go look for that resource in another location. This is
  # used in the case where a web page has moved to another location or
  # is no longer at the original location. The two most commonly used
  # redirection status codes are 301 Move Permanently and 302 Found.
if  short_url_opc
	short_url_opc.n_visits += 1  #incrementamos una visita
  	short_url_opc.save
	data = get_data
	visit = Visit.new(:ip => data['ip'], :country => data['countryName'], :countryCode => data['countryCode'], :city => data["city"],:latitud => data["latitude"], :longitud => data["longitude"], :shortened_url => short_url_opc, :created_at => Time.now)
	visit.save
        redirect  short_url_opc.url, 301
  else
	short_url.n_visits += 1  #incrementamos una visita
	short_url.save
	data = get_data
	visit = Visit.new(:ip => data['ip'], :country => data['countryName'], :countryCode => data['countryCode'], :city => data["city"],:latitud => data["latitude"], :longitud => data["longitude"], :shortened_url => short_url, :created_at => Time.now)	
	visit.save
        redirect short_url.url, 301
  end

end
=end


def get_geo
    xml = RestClient.get "http://freegeoip.net/xml/#{get_remote_ip(env)}"
    data = XmlSimple.xml_in(xml.to_s)
    {"ip" => data['Ip'][0].to_s, "countryCode" => data['CountryCode'][0].to_s, "countryName" => data['CountryName'][0].to_s, "city" => data['City'][0].to_s, "latitude" => data['Latitude'][0].to_s, "longitude" => data['Longitude'][0].to_s}
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