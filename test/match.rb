# Test the ~~ Match operator
require 'testml/lite'

TestML::Lite.new.testml = <<'...'
%TestML 0.1.0

Plan = 1;

"A super*** you are" ~~ "super*** you";
...
