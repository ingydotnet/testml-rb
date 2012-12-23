require 'testml/lite'
require 'testml_bridge'

TestML::Test.new do |t|
  t.tmlfile = 'testml/basics.tml'
  t.bridge = TestMLBridge
end
