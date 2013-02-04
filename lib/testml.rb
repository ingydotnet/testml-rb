##
# TestML - An Acmeist and Data Driven test framework

# Make sure tests have access to the application libs and the testing libs.
$:.unshift "#{Dir.getwd}/lib"
$:.unshift "#{Dir.getwd}/test/lib"

# Initialize the TestML namespace
class TestML;end
class TestML::Lite < TestML;end

# Load the various classes
require 'testml/bridge'
require 'testml/compiler'
require 'testml/lite/compiler'
require 'testml/runtime'
require 'testml/runtime/unit'
require 'testml/library'
require 'testml/library/standard'

#------------------------------------------------------------------------------
# Test files create TestML objects, which contain all the information needed by
# TestML to run a test.
class TestML
  VERSION = '0.0.2'

  # These attributes are the API for TestML.

  # TODO remove these 4:
  attr_accessor :assertions # XXX
  attr_accessor :data
  attr_accessor :plan
  attr_accessor :skip
  attr_accessor :function        # XXX this should be in runtime object

  attr_accessor :name
  attr_accessor :compiler_class  # combine with compiler (ie create compiler)
  attr_accessor :runtime_class   # combine with runtime

  attr_accessor :runtime
  attr_accessor :bridge
  attr_accessor :library

  def initialize attributes={}
    # Initialize the object attributes with defaults:
    @testfile = TestML.get_testfile
    @name = TestML.get_testname
    @compiler_class ||= TestML::Compiler
    @runtime_class = TestML::Runtime::Unit
    @bridge = TestML::Bridge.new
    @library = TestML::Library::Standard.new
    # TODO assertions and data should be nil by default
    @assertions = []
    @data = []
    @plan = nil
    @skip = false
    @run = false
    @function = TestML::Function.new

    # Set named attributes:
    attributes.each { |k,v| self.send "#{k}=", v }

    # Run caller block if given
    yield self if block_given?

    # Register this test object so that it can be called by the test framework
    # later on.
    @runtime_class.register self, @name
    @runtime = @runtime_class.new self
  end

  def bridge= bridge
    @bridge = (bridge.is_a? TestML::Bridge) ? bridge : bridge.new
  end

  def library= library
    @library = (library.is_a? TestML::Library) ? library : library.new
  end

  def testml= testml
    if not testml.match /\n/
      if not testml.match /^\//
        testml = "#{File.dirname @testfile}/#{testml}"
      end
      testml = File.read testml
    end
    @compiler ||= @compiler_class.new
    @function = @compiler.compile testml
  end

  # Finalize the TestML object and run it.
  def run
    return if @run
    if not @assertions.empty?
      @compiler ||= @compiler_class.new
      @function.statements = @assertions.map do |a|
        a.kind_of?(Array) ? a : @compiler.compile_assertion(a)
      end
    end
    @function.data = @data if not @data.empty?
    @function.setvar('Plan', @plan) if @plan
    @bridge.runtime = @runtime
    @library.runtime = @runtime
    @runtime.run
    @run = true
  end

  # Skip the test file unless we can require the requisite library(s)
  def required= *libraries
    libraries.flatten.each do |lib|
      begin
        require lib
      rescue LoadError
        @skip = "Can't require '#{lib}'. Skipping test."
        break
      end
    end
  end

  # Find the first call-stack entry that looks like: .../test/xxx-yyy.rb
  def self.get_testfile
    caller.map {|s| s.split(':').first} \
      .grep(/(^|\/)test\/[-\w]+\.rb$/).first
  end

  # Return something like 'test_xxx_yyy' as the test name.
  def self.get_testname
    name = TestML.get_testfile or return nil
    name.gsub!(/^(?:.*\/)?test\/([-\w+]+)\.rb$/, '\1') \
      .gsub!(/[^\w]+/, '_')
    return "test_#{name}"
  end
end

class TestML::Lite < TestML
  def initialize *args, &block
    @compiler_class = TestML::Lite::Compiler
    super *args, &block
  end
end
