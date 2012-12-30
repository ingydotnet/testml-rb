require 'testml/lite'
require 'testml_bridge'

TestML::Lite.new(
  tmlfile: 'testml/exceptions.tml',
  bridge: TestMLBridge,
)
