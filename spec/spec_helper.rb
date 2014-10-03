# Copyright (c) 2012-2013 Stark & Wayne, LLC

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)

require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

$:.unshift(File.expand_path("../../lib", __FILE__))

require "rspec/core"
require "tmpdir"
require "bosh-bootstrap"
require "bosh-bootstrap/cli/helpers"

# for the #sh helper
require "rake"
require "rake/file_utils"

# load all files in spec/support/* (but not lower down)
Dir[File.dirname(__FILE__) + '/support/*'].each do |path|
  require path unless File.directory?(path)
end

def spec_asset(filename)
  File.expand_path("../assets/#{filename}", __FILE__)
end

def files_match(filename, expected_filename)
  file = File.read(filename)
  expected_file = File.read(expected_filename)
  expect(file).to eq(expected_file)
end

def yaml_files_match(filename, expected_filename)
  yaml = YAML.load_file(filename)
  expected_yaml = YAML.load_file(expected_filename)
  expect(yaml).to eq(expected_yaml)
end

def setup_home_dir
  FileUtils.rm_rf(home_dir)
  FileUtils.mkdir_p(home_dir)
  ENV['HOME'] = home_dir
end

def setup_work_dir
  FileUtils.mkdir_p(work_dir)
  FileUtils.chdir(work_dir)
end

def work_dir
  File.join(home_dir, "workspace/deployments/microbosh")
end

def home_dir
  File.expand_path("../../tmp/home", __FILE__)
end

# returns the file path to a file
# in the fake $HOME folder
def home_file(*path)
  File.join(ENV['HOME'], *path)
end

# returns the file path to a file
# in the fake ~/workspace/deployments/microbosh folder
def work_file(*path)
  File.join(work_dir, *path)
end

RSpec.configure do |c|
  c.before(:each) do
    setup_home_dir
    setup_work_dir
  end

  c.color = true
end

def get_tmp_file_path(content)
  tmp_file = File.open(File.join(Dir.mktmpdir, "tmp"), "w")
  tmp_file.write(content)
  tmp_file.close

  tmp_file.path
end
