# Copyright (c) 2012-2013 Stark & Wayne, LLC

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

$:.unshift(File.expand_path("../../lib", __FILE__))

require "rspec/core"
require "bosh/providers"
require "bosh-bootstrap"
require "bosh-bootstrap/cli"

# for the #sh helper
require "rake"
require "rake/file_utils"

def spec_asset(filename)
  File.expand_path("../assets/#{filename}", __FILE__)
end

def files_match(filename, expected_filename)
  file = File.read(filename)
  expected_file = File.read(expected_filename)
  file.should == expected_file
end

def setup_home_dir
  home_dir = File.expand_path("../../tmp/home", __FILE__)
  FileUtils.rm_rf(home_dir)
  FileUtils.mkdir_p(home_dir)
  ENV['HOME'] = home_dir

  private_key = File.join(home_dir, ".ssh", "id_rsa")
  unless File.exists?(private_key)
    puts "Creating private keypair for inception VM specs..."
    mkdir_p(File.dirname(private_key))
    sh "ssh-keygen -f #{home_dir}/.ssh/id_rsa -N ''"
  end
end

RSpec.configure do |c|
  c.before(:each) do
    setup_home_dir
  end

  c.color_enabled = true
end

def get_tmp_file_path(content)
  tmp_file = File.open(File.join(Dir.mktmpdir, "tmp"), "w")
  tmp_file.write(content)
  tmp_file.close

  tmp_file.path
end
