require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"
require "pry"

$:.push File.dirname(__FILE__)
require "weixin_bot_cli"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

desc "Open console"
task :console do
  pry
end

desc "Run bot"
task :run do
  WeixinBotCli::Bot.new(WeixinBotCli::Bot.get_uuid).run
end

desc "Get fake contact"
task :get_fake_contact do
  uuid = WeixinBotCli::Bot.get_uuid
  bot = WeixinBotCli::Bot.new(uuid)
  bot.show_login_qrcode
  bot.confirm_login
  bot.get_cookie
  bot.get_init_info
  bot.open_status_notify
  bot.get_contact
  bot.get_group_member
  bot.get_fake_contact
end

task default: :console
