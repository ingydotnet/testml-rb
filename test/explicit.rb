# Use the explicit TestML::Test API
require 'testml'
require 'testml_bridge'

test = TestML.new do |t|
  t.plan = 2
  t.bridge = TestMLBridge
end

test.assertions << "*upper.lowercase == *lower"

# Define an explicit function for:
#   *upper == *lower.uppercase;
test.assertions << [
  'EQ',
  '*upper',
  ['uppercase', '*lower'],
]

test.data << {
    :label => "My test",
    :points => {
      'upper' => "I LIKE PI",
      'lower' => "i like pi",
    },
  }

test.skip = false
