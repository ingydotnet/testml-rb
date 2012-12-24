# Use the explicit TestML::Test API
require 'testml/lite'
require 'testml_bridge'

test = TestML::Test.new do |t|
  t.plan = 2
  t.bridge = TestMLBridge
end

test.function << "*upper.lowercase == *lower"
# Define an explicit function for:
#   *upper == *lower.uppercase;
test.function << [
  'Equal',
  '*upper',
  ['uppercase', '*lower'],
]

test.blocks = [
  {
    :label => "My test",
    :points => {
      'upper' => "I LIKE PI",
      'lower' => "i like pi",
    },
  }
]

test.skip = false
