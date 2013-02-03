guard 'rspec' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/bosh-bootstrap/(.+)\.rb$})    { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }
end

