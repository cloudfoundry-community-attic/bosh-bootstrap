# Copyright (c) 2012-2013 Stark & Wayne, LLC

require File.expand_path("../../spec_helper", __FILE__)

describe Bosh::Bootstrap::Helpers::SettingsSetter do
  include Bosh::Bootstrap::Helpers::SettingsSetter

  attr_reader :settings
  before do
    @settings = {}
  end

  def save_settings!
  end

  it "with_setting 'a'" do
    with_setting "a" do |setting|
      setting['value'] = "abc"
    end
    settings["a"]["value"].should == "abc"
  end

  it "with_setting 'a.b.c'" do
    with_setting "a.b.c" do |setting|
      setting['value'] = "abc"
    end
    settings["a"]["b"]["c"]["value"].should == "abc"
  end
end