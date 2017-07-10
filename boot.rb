$:.push File.dirname(__FILE__)
APP_ROOT = File.dirname(__FILE__)
APP_ENV = ENV['APP_ENV']

require 'bundler'
Bundler.require(:default)
Bundler.require(:development) if APP_ENV == "development"
require 'active_support/all'
require 'logger'
require 'json'

Dir.glob(APP_ROOT + "/lib/**/*.rb").each{|f| require f }

def client
  @client ||= Faraday.new
end

def logger
  @logger ||= Logger.new STDOUT
end

def get_timestamp
  String(Time.now.to_i*1000+Random.rand(999))
end

def get_device_id
  "e#{Random.rand(10**15).to_s.rjust(15,'0')}"
end

WEIXIN_APPID = 'wx782c26e4c19acffb'

