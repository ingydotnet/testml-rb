$:.unshift "#{Dir.getwd}/lib"
$:.unshift "#{Dir.getwd}/test/lib"

require 'testml'
require 'testml/compiler/lite'
require 'testml_bridge'

TestML.new(
  testml: '../testml/semicolons.tml',
  bridge: TestMLBridge,
  compiler: TestML::Compiler::Lite,
)
