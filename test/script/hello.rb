require 'testml'
require 'test/unit'
class Test::Hello < Test::Unit::TestCase
  def test
    TestML.new(
      testml: testml,
    ).run(self)
  end
  def testml
    <<'...'
%TestML 0.1.0
Plan = 1
Print("Goodbye, World!\n")
1.OK
...
  end
end
