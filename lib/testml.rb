class TestML
  VERSION = '0.0.2'

  attr_accessor :runtime
  attr_accessor :compiler
  attr_accessor :bridge
  attr_accessor :library
  attr_accessor :testml

  require 'testml/runtime/unit'
  require 'testml/compiler/pegex'
  require 'testml/bridge'
  require 'testml/library/standard'
  require 'testml/library/debug'

  def initialize attributes={}
    defaults = {
      'runtime' => TestML::Runtime::Unit,
      'compiler' => TestML::Compiler::Pegex,
      'bridge' => TestML::Bridge,
      'library' => [
        TestML::Library::Standard,
        TestML::Library::Debug,
      ],
    }
    defaults.merge(attributes).each { |k,v| self.send "#{k}=", v }

    @runtime.register self
  end

  def run
    @runtime.new(
      compiler: @compiler,
      bridge: @bridge,
      library: @library,
      testml: @testml,
    ).run
  end
end

# XXX Eliminate these. Make dynamic.
require 'testml/runtime/unit'
require 'testml/library/standard'
require 'testml/library/debug'
