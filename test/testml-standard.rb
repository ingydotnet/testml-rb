require 'test/unit'
require 'testml'
require 'testml/compiler/pegex'
require_relative 'testml_bridge'

class Test::TestML < Test::Unit::TestCase
  def test_standard_tml(compiler=TestML::Compiler::Pegex)
    TestML.new(
      testml: 'testml/standard.tml',
      bridge: TestMLBridge,
      compiler: compiler,
    ).run(self)
  end
end
