# Clean up Ci

Currently, the travis runs are not self-destroying the servers. If CI fails, ask @drnic to run:

```
fog = Fog::Compute::AWS.new(Fog.credentials.merge(region: 'us-east-1'))
fog.security_groups.select {|sg| p sg.name =~ /inception-vm/}.each {|sg| fog.servers.select {|s| s.security_group_ids.include? sg.group_id}.each {|s| puts s; s.destroy}}; nil
```
