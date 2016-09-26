Gem::Specification.new do |s|
  s.name          = 'facebook-cli'
  s.version       = '1.3.5'
  s.licenses      = ['MIT']
  s.summary       = 'Facebook command line utility'
  s.description   = 'A limited command line interface to the Facebook Graph API'
  s.authors       = ['Ildar Sagdejev']
  s.email         = 'specious@gmail.com'
  s.files         = Dir['lib/**/*.rb', 'bin/facebook-cli']
  s.require_paths = ['lib']
  s.executables   = ['facebook-cli']
  s.homepage      = 'https://github.com/specious/facebook-cli'
  s.required_ruby_version = '>= 2.3'
end