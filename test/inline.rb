require 'test/unit'
require 'testml'
require_relative 'testml_bridge'

class Test::Inline < Test::Unit::TestCase
  def test
    TestML.new(
      testml: testml,
      bridge: TestMLBridge,
    ).run(self)
  end

  def testml
    <<'...'
%TestML 0.1.0

Title = "Ingy's Test";
Plan = 4;

*foo == *bar;
*bar == *foo;

=== Foo for thought
--- foo: O HAI
--- bar: O HAI

=== Bar the door
--- bar
O
HAI
--- foo
O
HAI
...
  end
end
