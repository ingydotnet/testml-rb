require 'testml'
require 'testml_bridge'

TestML::Lite.new(
  testml: '../testml/exceptions.tml',
  bridge: TestMLBridge,
)
