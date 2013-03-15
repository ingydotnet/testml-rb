require 'test/unit'

require 'testml/runtime'
require 'testml/compiler/pegex'
require 'testml/compiler/lite'
require 'yaml'

class TestCompileLite < Test::Unit::TestCase
  def test_compile_lite
    testml = <<'...'
# A comment
%TestML 0.1.0

Plan = 2;
Title = "O HAI TEST";

*input.uppercase == *output;

=== Test mixed case string
--- input: I Like Pie
--- output: I LIKE PIE

=== Test lower case string
--- input: i love lucy
--- output: I LOVE LUCY
...

    func = TestML::Compiler::Pegex.new.compile(testml)
    func_lite = TestML::Compiler::Lite.new.compile(testml)

    assert_equal YAML.dump(func_lite), YAML.dump(func),
      'Lite compile matches normal compile'
  end
end
