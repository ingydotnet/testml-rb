$:.unshift "#{Dir.getwd}/test/lib"

require 'testml'
require 'testml_bridge'

TestML.new(
  testml: 'testml/arguments.tml',
  bridge: TestMLBridge,
)
