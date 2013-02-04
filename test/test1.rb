require 'testml'
require 'testml_bridge'

TestML.new do |t|
  t.required = 'json', 'yaml'
  t.bridge = TestMLBridge
  t.testml = <<'...'
Plan = 1;

*json.json_load.yaml_dump == *yaml;

=== Array
--- json: [1,2,3]
--- yaml
- 1
- 2
- 3
...
end
