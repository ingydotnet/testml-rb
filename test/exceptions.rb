$:.unshift "#{Dir.getwd}/test/lib"

require 'testml'
require 'testml_bridge'

TestML.new(
  testml: 'testml/exceptions.tml',
  bridge: TestMLBridge,
)
