require 'testml/lite'

test = TestML::Test.new
test.plan = 3
test.function = [
  "'x' == 'x'",
  "12 == 12",
  "'OK' == 'OK'",
]
