# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'weixin_bot_cli/version'

Gem::Specification.new do |spec|
  spec.name          = "weixin_bot_cli"
  spec.version       = WeixinBotCli::VERSION
  spec.authors       = ["Andersen Fan"]
  spec.email         = ["as181920@gmail.com"]

  spec.summary       = %q{weixin bot command line library}
  spec.description   = %q{weixin bot as a web weixin client}
  spec.homepage      = "http://gitlab.io-note.com/weixin.message.handler/weixin_bot_cli"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "http://gems.io-note.com"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
  spec.add_dependency "faraday"
  spec.add_dependency "faraday-cookie_jar"
  spec.add_dependency "rqrcode"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry-byebug"
end
