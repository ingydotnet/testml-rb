require 'testml/lite'

test = TestML::Lite.new
test.plan = 3
test.assertions = [
  "'xyzzy' == 'xyzzy'",
  "123 == 123",
  "'OKOKOK' ~~ 'OK'",
]
