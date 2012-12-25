require 'testml/lite'
require 'testml_bridge'

TestML::Test.new(
  testname: 'test_attributes',
  tmlfile: 'testml/basics.tml',
  bridge: TestMLBridge,
  skip: false,
  plan: 123,
)
