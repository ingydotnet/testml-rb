require 'test/unit'
require 'testml'
require 'testml/compiler/lite'
require_relative 'testml_bridge'

class Test::TestML < Test::Unit::TestCase
  def test_basic_tml(compiler=TestML::Compiler::Lite)
    TestML.new(
      testml: 'testml/basic.tml',
      bridge: TestMLBridge,
      compiler: compiler,
    ).run(self)
  end
end
