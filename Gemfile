source 'https://rubygems.org'

gemspec

# Need to overwrite SSL settings
gem "excon"

if File.directory?("../cyoi")
  gem "cyoi", path: "../cyoi"
end

group :development do
  gem "awesome_print"
  gem "rb-fsevent", "~> 0.9.1"
  gem "guard-rspec"
end
