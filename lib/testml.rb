class TestML
  VERSION = '0.0.2'

  attr_accessor :runtime
  attr_accessor :compiler
  attr_accessor :bridge
  attr_accessor :library
  attr_accessor :testml

  def initialize attributes={}
    defaults = {}
    if not attributes['runtime']
      require 'testml/runtime/unit'
      defaults['runtime'] = TestML::Runtime::Unit
    end
    if not attributes['compiler']
      require 'testml/compiler/pegex'
      defaults['compiler'] = TestML::Compiler::Pegex
    end
    if not attributes['bridge']
      require 'testml/bridge'
      defaults['bridge'] = TestML::Bridge
    end
    if not attributes['library']
      require 'testml/library/standard'
      require 'testml/library/debug'
      defaults['library'] = [
        TestML::Library::Standard,
        TestML::Library::Debug,
      ]
    end
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
