require 'testml'
require 'testml_bridge'

TestML.new(
  name: 'test_attributes',
  testml: 'testml/basics.tml',
  bridge: TestMLBridge,
  skip: false,
)
