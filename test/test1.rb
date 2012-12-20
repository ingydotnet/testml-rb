require './test/lib/test_testml_lite'

TestML.require_or_skip 'json'
TestML.require_or_skip 'yaml'

TestML.run do |t|
  t.eval '*json.json_load.yaml_dump == *yaml'
end

TestML.data <<'...'
=== Array
--- json: [1,2,3]
--- yaml
- 1
- 2
- 3
...
