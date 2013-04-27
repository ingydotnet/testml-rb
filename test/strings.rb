require 'test/unit'
require 'testml'

class Test::Strings < Test::Unit::TestCase
  def test
    TestML.new(
      testml: testml,
      bridge: TestMLBridge,
    ).run(self)
  end

  def testml
    <<'...'
%TestML 0.1.0

Plan = 6

Throw(*error).bogus().Catch() == *error
*error.Throw().bogus().Catch() == *error
Throw('My error message').Catch() == *error

*empty == "".Str
*empty == ""

Label = 'Simple string comparison'
"foo" == "foo"

=== Throw/Catch
--- error: My error message

=== Empty Point
--- empty
...
  end
end
