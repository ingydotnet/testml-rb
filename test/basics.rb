require 'testml/lite'
require 'testml_bridge'

TestML::Test.new(
  tmlfile: 'testml/basics.tml',
  bridge: TestMLBridge,
)
