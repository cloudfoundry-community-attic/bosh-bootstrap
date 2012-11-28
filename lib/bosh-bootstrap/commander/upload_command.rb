# A single command/script to be run on a local/remote server
# For the display, it has an active ("installing") and 
# past tense ("installed") verb and a noub/description ("packages")
module Bosh::Bootstrap::Commander
  class UploadCommand < Command
    def initialize(target_path, file_contents)
      super("upload", "file", "uploading file", "uploaded file")
      @target_path = target_path
      @file_contents = file_contents
    end

    # Invoke this command to call back upon +server.upload_file+ 
    def perform(server)
      server.upload_file(self, @target_path, @file_contents)
    end
  end
end