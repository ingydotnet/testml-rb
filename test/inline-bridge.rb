require 'testml'
require 'testml/bridge'
require 'testml/util'
include TestML::Util

class Bridge < TestML::Bridge
  def upper(string)
    str string.value.upcase
  end
end

TestML.new(
    bridge: Bridge,
).testml = <<'...'
%TestML 0.1.0

*foo.upper() == *bar

=== Foo for thought
--- foo: o hai
--- bar: O HAI

=== Bar the door
--- foo
o
Hai
--- bar
O
HAI
...
