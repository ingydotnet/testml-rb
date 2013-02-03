require 'testml/lite'
require 'testml_bridge'

TestML::Lite.new(
  testml: 'testml/semicolons.tml',
  bridge: TestMLBridge,
)
