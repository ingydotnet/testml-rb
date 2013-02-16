require 'testml'
require 'testml_bridge'

TestML::Lite.new(
  testml: 'testml/basic.tml',
  bridge: TestMLBridge,
)
