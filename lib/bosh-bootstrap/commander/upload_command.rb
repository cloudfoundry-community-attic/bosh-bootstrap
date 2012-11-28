# A single command/script to be run on a local/remote server
# For the display, it has an active ("installing") and 
# past tense ("installed") verb and a noub/description ("packages")
module Bosh::Bootstrap::Commander
  class UploadCommand < Command
    def initialize(file_contents, target_location)
      super("upload", "file", "uploading file", "uploaded file")
    end
  end
end