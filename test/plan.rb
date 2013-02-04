require 'testml'

test = TestML.new
test.plan = 3
test.assertions = [
  "'xyzzy' == 'xyzzy'",
  "123 == 123",
  "'OKOKOK' ~~ 'OK'",
]
