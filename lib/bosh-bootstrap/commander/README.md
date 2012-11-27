# Bosh::Bootstrap::Commander

The sequence of commands that are run on an Inception VM can be either invoked locally on the Inception VM or from a remote machine. The `Commander` provides a DSL for describing the commands to be run and allows them to be sequentially run against a local or remote server.

Remote servers are accessed via SSH commands.

Example commands:
``` ruby
@local_machine.run(commands)
@server.run(commands)

# where
commands = Bosh::Bootstrap::Commander::Commands.new do |server|
  server.create "vcap user", <<-BASH
    #!/usr/bin/env bash
    
    groupadd vcap 
    useradd vcap -m -g vcap
    mkdir -p /home/vcap/.ssh
    chown -R vcap:vcap /home/vcap/.ssh
  BASH

  server.install "rvm & ruby", <<-BASH
    #!/usr/bin/env bash
    
    if [[ -x rvm ]]
    then
      rvm get stable
    else
      curl -L get.rvm.io | bash -s stable
      source /etc/profile.d/rvm.sh
    fi
    command rvm install 1.9.3 # oh god this takes a long time
    rvm 1.9.3
    rvm alias create default 1.9.3
  BASH
end
```

You can invoke any method upon `server` and it will be supported as the command name. The name of the method invoked is semantically meaningless; it is a convenience. There is a set of predefined command methods which give nicer text output:

* `assign`
* `create`
* `download`
* `install`
* `provision`
* `store`
