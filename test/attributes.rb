require 'testml/lite'
require 'testml_bridge'

TestML::Lite.new(
  testname: 'test_attributes',
  tmlfile: 'testml/basics.tml',
  bridge: TestMLBridge,
  skip: false,
)
