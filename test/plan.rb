require 'testml/lite'

test = TestML::Test.new
test.plan = 3
test.function = [
  "'xyzzy' == 'xyzzy'",
  "123 == 123",
  "'OKOKOK' ~~ 'OK'",
]
