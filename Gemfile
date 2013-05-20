source 'https://rubygems.org'
source 'https://s3.amazonaws.com/bosh-jenkins-gems/'

gemspec

if File.directory?("../cyoi")
  gem "cyoi", path: "../cyoi"
end

group :development do
  gem "awesome_print"
  gem "rb-fsevent", "~> 0.9.1"
  gem "guard-rspec"
end
