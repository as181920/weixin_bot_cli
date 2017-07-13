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

task default: :console
