require 'testml'
require 'testml_bridge'

TestML::Lite.new(
  testml: '../testml/arguments.tml',
  bridge: TestMLBridge,
)
