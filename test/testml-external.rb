require 'test/unit'
require 'testml'
require 'testml/compiler/pegex'
require_relative 'testml_bridge'

class Test::TestML < Test::Unit::TestCase
  def test_external_tml(compiler=TestML::Compiler::Pegex)
    TestML.new(
      testml: 'testml/external.tml',
      bridge: TestMLBridge,
      compiler: compiler,
    ).run(self)
  end
end
