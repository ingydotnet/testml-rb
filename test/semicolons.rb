$:.unshift "#{Dir.getwd}/lib"
$:.unshift "#{Dir.getwd}/test/lib"

require 'testml'
require 'testml_bridge'

TestML.new(
  testml: 'testml/semicolons.tml',
  bridge: TestMLBridge,
)
