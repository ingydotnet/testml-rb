# Use the explicit TestML::Test API
require 'testml/lite'
require 'testml_bridge'

test = TestML::Test.new do |t|
  t.plan = 2
  t.bridge = TestMLBridge
end

test.assertions << "*upper.lowercase == *lower"

# Define an explicit function for:
#   *upper == *lower.uppercase;
test.assertions << [
  'Equal',
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
