require 'test/unit'

require 'testml/runtime'
require 'testml/compiler/pegex'

class TestCompileTestMLDocument < Test::Unit::TestCase
  def test_compile_testml_document
    testml = <<'...'
# A comment
%TestML 0.1.0

Plan = 2
Title = "O HAI TEST"

*input.uppercase() == *output

=== Test mixed case string
--- input: I Like Pie
--- output: I LIKE PIE

=== Test lower case string
--- input: i love lucy
--- output: I LOVE LUCY
...

    func = TestML::Compiler::Pegex.new.compile(testml)
    assert func, 'TestML string matches against TestML grammar'
    assert_equal func.namespace['TestML'].value, '0.1.0', 'Version parses'
    assert_equal func.statements[0].expr.value, 2, 'Plan parses'
    assert_equal func.statements[1].expr.value, 'O HAI TEST', 'Title parses'
    assert_equal func.statements[1].expr.value, 'O HAI TEST', 'Title parses'

    assert_equal func.statements.size, 3, 'Three test statements'
    statement = func.statements[2]
    assert_equal statement.points.join('-'), 'input-output',
        'Point list is correct'

    assert_equal statement.expr.calls.size, 2, 'Expression has two calls'
    expr = statement.expr
    assert expr.calls[0].kind_of?(TestML::Point), 'First sub is a Point'
    assert_equal expr.calls[0].name, 'input', 'Point name is "input"'
    assert_equal expr.calls[1].name, 'uppercase', 'Second sub is "uppercase"'

    assert_equal statement.assert.name, 'EQ', 'Assertion is "EQ"'

    expr = statement.assert.expr
    assert expr.kind_of?(TestML::Point), 'First sub is a Point'
    assert_equal expr.name, 'output', 'Point name is "output"'

    assert_equal func.data.size, 2, 'Two data blocks'
    (block1, block2) = func.data
    assert_equal block1.label, 'Test mixed case string', 'Block 1 label ok'
    assert_equal block1.points['input'], 'I Like Pie', 'Block 1, input point'
    assert_equal block1.points['output'], 'I LIKE PIE', 'Block 1, output point'
    assert_equal block2.label, 'Test lower case string', 'Block 2 label ok'
    assert_equal block2.points['input'], 'i love lucy', 'Block 2, input point'
    assert_equal block2.points['output'], 'I LOVE LUCY', 'Block 2, output point'
  end
end
