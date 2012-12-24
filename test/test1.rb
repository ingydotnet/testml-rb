require 'testml/lite'
require 'testml_bridge'

testml = TestML::Test.new do |t|
  t.require_or_skip 'json', 'yaml'
  t.bridge = TestMLBridge
  t.document = <<'...'
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
