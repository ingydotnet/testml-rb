# Test the ~~ Match operator
require 'testml/lite'

TestML::Test.new.document = <<'...'
%TestML 0.1.0

Plan = 1;

"A super*** you are" ~~ "super*** you";
...
