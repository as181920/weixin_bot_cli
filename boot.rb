$:.push File.dirname(__FILE__)
APP_ROOT = File.dirname(__FILE__)
APP_ENV = ENV['APP_ENV']

require 'bundler'
Bundler.require(:default)
Bundler.require(:development) if APP_ENV == "development"
require 'active_support/all'
require 'logger'
require 'json'

require_relative "lib/version"
require_relative "lib/application_record"
Dir.glob(APP_ROOT + "/lib/**/*.rb").each{|f| require f }

def client
  @client ||= Faraday.new
end

def logger
  @logger ||= Logger.new STDOUT
end

