# Test the ~~ Match operator
require 'testml'

TestML.new.testml = <<'...'
%TestML 0.1.0

Plan = 1;

"A super*** you are" ~~ "super*** you";
...
