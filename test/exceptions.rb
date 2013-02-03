require 'testml/lite'
require 'testml_bridge'

TestML::Lite.new(
  testml: 'testml/exceptions.tml',
  bridge: TestMLBridge,
)
