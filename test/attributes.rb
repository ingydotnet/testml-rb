require 'testml/lite'
require 'testml_bridge'

TestML::Lite.new(
  name: 'test_attributes',
  testml: 'testml/basics.tml',
  bridge: TestMLBridge,
  skip: false,
)
