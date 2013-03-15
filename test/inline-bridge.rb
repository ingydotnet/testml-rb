require 'testml'
require 'testml/bridge'

class Bridge < TestML::Bridge
  def upper(string)
    string.value.upcase
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
