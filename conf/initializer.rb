require "excon"

# Used for specific modifiers for Excon / SSL settings
# 
# ENV['SSL_CERT_DIR'] = 'path_to_certs'
# ENV['SSL_CERT_FILE'] = 'path_to_file'
# Excon.defaults[:ssl_ca_path] = ENV['SSL_CERT_DIR']
# Excon.defaults[:ssl_ca_file] = ENV['SSL_CERT_FILE']
#
# or
#
# Excon.defaults[:ssl_verify_peer] = false