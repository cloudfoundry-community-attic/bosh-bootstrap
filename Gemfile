source 'https://rubygems.org'

gemspec

# Ensure bosh-bootstrap & bosh micro support same gems for traveling-bosh
gem "bosh_cli_plugin_micro"

if File.directory?("../cyoi")
  gem "cyoi", path: "../cyoi"
end

gem "unf"
group :development do
  gem "awesome_print"
  gem "rb-fsevent", "~> 0.9.1"
  gem "guard-rspec"
end
