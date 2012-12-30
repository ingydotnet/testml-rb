require 'testml/lite'
require 'testml_bridge'

TestML::Lite.new(
  tmlfile: 'testml/semicolons.tml',
  bridge: TestMLBridge,
)
