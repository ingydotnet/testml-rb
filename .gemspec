# encoding: utf-8

GemSpec = Gem::Specification.new do |gem|
  gem.name = 'testml'
  gem.version = '0.0.1'
  gem.license = 'MIT'
  gem.required_ruby_version = '>= 1.9.1'

  gem.authors << 'Ingy döt Net'
  gem.email = 'ingy@ingy.net'
  gem.summary = 'Acmeist Unit Test Framework'
  gem.description = <<-'.'
TestML is an Acmeist testing framework.
.
  gem.homepage = 'http://testml.org'

  gem.files = `git ls-files`.lines.map{|l|l.chomp}
end
