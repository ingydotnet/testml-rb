require 'test/unit'
require 'testml'
require 'testml/util'
require_relative 'testml_bridge'
include TestML::Util

class Bridge < TestML::Bridge
  def upper(string)
    str string.value.upcase
  end
end

class Test::InlineBridge < Test::Unit::TestCase
  def test
    TestML.new(
      testml: testml,
      bridge: Bridge,
    ).run(self)
  end

  def testml
    <<'...'
%TestML 0.1.0

Plan = 2
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
  end
end
