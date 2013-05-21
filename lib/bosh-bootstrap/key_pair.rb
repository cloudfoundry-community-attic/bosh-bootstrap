require "fileutils"

class Bosh::Bootstrap::KeyPair
  include FileUtils

  attr_reader :base_path, :keyname, :private_key

  def initialize(base_path, keyname, private_key)
    @base_path, @keyname, @private_key = base_path, keyname, private_key
  end

  def execute!
    mkdir_p(File.dirname(path))
    chmod(0700, File.dirname(path))

    File.open(path, "w") { |file| file << private_key }
    chmod(0600, path)
  end

  def path
    @path ||= File.join(base_path, "ssh", keyname)
  end
end
