guard 'rspec', spec_paths: ["spec/unit"] do
  watch(%r{^spec/unit/(.+_spec)\.rb$})
  watch(%r{^lib/bosh-bootstrap/(.+)\.rb$})    { |m| "spec/unit/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec/unit" }
end

