require 'testml/lite'
require 'testml_bridge'

TestML::Lite.new(
  tmlfile: 'testml/basics.tml',
  bridge: TestMLBridge,
)
