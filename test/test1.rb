require 'testml/lite'
require 'testml_bridge'

TestML.require_or_skip 'json', 'yaml'

testml = TestML::Test.new

testml.bridge = TestMLBridge

testml.function << '*json.json_load.yaml_dump == *yaml'

testml.document = <<'...'
=== Array
--- json: [1,2,3]
--- yaml
- 1
- 2
- 3
...
