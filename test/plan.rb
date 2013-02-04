require 'testml'

test = TestML::Lite.new
test.testml = <<'...'
Plan = 3

'xyzzy' == 'xyzzy'
123 == 123
'OKOKOK' ~~ 'OK'
...
