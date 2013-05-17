module AwsHelpers
  def keep_after_test?
    ENV['KEEP_AFTER_TEST']
  end

  def unique_number
    ENV['UNIQUE_NUMBER'] || Random.rand(100000)
  end

  def create_manifest(options = {})
    setting "provider.name", "aws"
    setting "provider.region", "us-east-1"
    setting "provider.credentials.aws_access_key_id", ENV['AWS_ACCESS_KEY_ID']
    setting "provider.credentials.aws_secret_access_key", ENV['AWS_SECRET_ACCESS_KEY']
    options.each { |key, value| setting(key, value) }
    unless settings.exists?("provider.credentials.aws_secret_access_key")
      raise "Please provided $AWS_ACCESS_KEY_ID and $AWS_SECRET_ACCESS_KEY"
    end
  end

  def destroy_test_constructs
    puts "Destroying everything created by previous tests..."
    provider.cleanup_unused_ip_addresses
  end

end