#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'haml'
require 'uri'
require 'pp'
#require 'socket'
require 'data_mapper'
require 'omniauth-oauth2'      
require 'omniauth-google-oauth2'


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
$email = ""

#Control del OmniAuth
use OmniAuth::Builder do       
  config = YAML.load_file 'config/config.yml'
  provider :google_oauth2, config['identifier'], config['secret']
end
  
enable :sessions               
set :session_secret, '*&(^#234a)'


get '/' do
    @list = ShortenedUrl.all(:order => [ :id.asc ], :limit => 20,:usuario => $email)
  haml :index
end

#Cuando es redirigido de Omniauth
get '/auth/:name/callback' do
    @auth = request.env['omniauth.auth']
    $email = @auth['info'].email
    @list = ShortenedUrl.all(:order => [ :id.asc ], :limit => 20, :usuario => $email)
  haml :index
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
        @short_url = ShortenedUrl.first_or_create(:url => params[:url], :url_opc => params[:url_opc], :usuario => $email)
      else
        @short_url_opc = ShortenedUrl.first_or_create(:url => params[:url], :url_opc => params[:url_opc], :usuario => $email)
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

get '/:shortened' do
  short_url = ShortenedUrl.first(:id => params[:shortened].to_i(Base), :usuario => $email)
  short_url_opc = ShortenedUrl.first(:url_opc => params[:shortened])

  if short_url_opc  #Si tiene información, entonces devolvera la url corta
    redirect short_url_opc.url, 301
  else
    redirect short_url.url, 301
  end
end


error do haml :index end