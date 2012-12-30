# TestML::Lite - A Simpler Version of TestML


# TODO Move classes to separate files


# XXX
require 'yaml'; def XXX *args; args.each {|a|puts YAML.dump a}; exit; end


# Make sure tests have access to the application libs and the testing libs.
$:.unshift "#{Dir.getwd}/lib"
$:.unshift "#{Dir.getwd}/test/lib"

# Define the base TestML module
# TODO Move helper methods to TestML::Lite
#      This module should not collide with TestML
module TestML
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

#------------------------------------------------------------------------------
# Test files create TestML::Lite objects, which contain all the information
# needed by TestML to run a test.
class TestML::Lite
  VERSION = '0.0.2'

  # These attributes are the API for TestML::Lite.
  attr_accessor :assertions
  attr_accessor :data
  attr_accessor :plan
  attr_accessor :skip

  attr_accessor :testname
  attr_accessor :compiler_class
  attr_accessor :runtime_class

  attr_accessor :function
  attr_accessor :runtime
  attr_accessor :bridge
  attr_accessor :library

  def initialize attributes={}
    # Initialize the object attributes with defaults:
    @testfile = TestML.get_testfile
    @testname = TestML.get_testname
    @compiler_class = TestML::Lite::Compiler
    @runtime_class = TestML::Lite::Runtime::Unit
    @bridge = TestML::Lite::Bridge.new
    @library = TestML::Lite::Library::Standard.new
    # TODO assertions and data should be nil by default
    @assertions = []
    @data = []
    @plan = nil
    @skip = false
    @run = false
    @function = TestML::Lite::Function.new

    # Set named attributes:
    attributes.each { |k,v| self.send "#{k}=", v }

    # Run caller block if given
    yield self if block_given?

    # Register this test object so that it can be called by the test framework
    # later on.
    @runtime_class.register self, @testname
    @runtime = @runtime_class.new self
  end

  def bridge= bridge
    @bridge = (bridge.is_a? TestML::Lite::Bridge) ? bridge : bridge.new
  end

  def library= library
    @library = (library.is_a? TestML::Lite::Library) ? library : library.new
  end

  def document= document
    @compiler ||= @compiler_class.new
    @function = @compiler.compile document
  end

  def tmlfile= file
    if not file.match /^\//
      file = "#{File.dirname @testfile}/#{file}"
    end
    self.document = File.read file
  end

  # Finalize the TestML::Lite object and run it.
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

  # TODO Change this to required=
  # Skip the test file unless we can require the requisite library(s)
  def require_or_skip library, *libraries
    libraries.unshift library
    libraries.each do |lib|
      begin
        require lib
      rescue LoadError
        @skip = "Can't require '#{lib}'. Skipping test."
        break
      end
    end
  end
end

#------------------------------------------------------------------------------
# This is the Lite version of the TestML compiler. It can parse
# simple statements and assertions and also parse the TestML data
# format.
class TestML::Lite::Compiler
  attr_accessor :function
  # TODO put plan into Plan var in @function
  attr_accessor :plan
  attr_accessor :testml_version

  # support assignment statement for any variable
  def compile document
    @function = TestML::Lite::Function.new
    lines = document.lines.to_a.map &:chomp
    while not lines.empty?
      line = lines.shift
      next unless line.match /\S/
      next if line.match /^\s*#/
      if line[0..2] == "==="
        lines.unshift line
        break
      end
      if line.rstrip.match /^%TestML +(\d+\.\d+\.\d+)$/
        @testml_version = $1
      elsif line.strip.match /^Plan *= *(\d+);?$/
        @function.setvar('Plan', $1.to_i)
      elsif line.strip.match /^.*(?:==|~~).*;?$/
        @function.statements << compile_assertion(line.sub /;$/, '')
      else
        lines.unshift line
        fail "Failed to parse TestML::Lite document, here:\n" +
          lines.join($/)
      end
    end
    unless lines.empty?
      @function.data = compile_data lines.push('').join $/
    end
    return @function
  end

  def compile_assertion expr
    left, op, right = [], nil, nil
    side = left
    while expr.length != 0
      token = get_token expr
      if token =~ /^(==|~~)$/
        op = token == '==' ? 'EQ' : 'HAS'
        left = side
        side = right = []
      else
        side = [side] if side.size >= 2
        side.unshift token
      end
    end
    right = side if right
    return left unless right
    left = left.first if left.size == 1
    right = right.first if right.size == 1
    return [op, left, right]
  end

  def get_token expr
    if expr.sub! /^(\w+)\(([^\)]+)\)\.?/, ''
      token, args = [$1], $2
      token.concat(
        args.split(/,\s*/).map {|t| t.sub /^(['"])(.*)\1$/, '\2'}
      )
    elsif expr.sub! /^\s*(==|~~)\s*/, ''
      token = $1
    elsif expr.sub! /^(['"])(.*?)\1/, ''
      token = ['String', $2]
    elsif expr.sub! /^(\d+)\1/, ''
      token = ['Number', $2]
    elsif expr.sub! /^([\*\w]+)\.?/, ''
      token = $1
    else
      fail "Can't get token from '#{expr}'"
    end
    return token
  end

  def compile_data string
    string.gsub! /^#.*\n/, ''
    string.gsub! /^\\/, ''
    string.gsub! /^\s*\n/, ''
    blocks = string.split /(^===.*?(?=^===|\z))/m
    blocks.reject!{|b| b.empty?}
    blocks.each do |block|
      block.gsub! /\n+\z/, "\n"
    end

    data = []
    blocks.each do |string_block|
      block = {}
      string_block.gsub! /^===\ +(.*?)\ *\n/, '' \
        or fail "No block label! #{string_block}"
      block[:label] = $1
      while !string_block.empty? do
        if string_block.gsub! /\A---\ +(\w+):\ +(.*)\n/, '' or
           string_block.gsub! /\A---\ +(\w+)\n(.*?)(?=^---|\z)/m, ''
          key, value = $1, $2
        else
          raise "Failed to parse TestML string:\n#{string_block}"
        end
        block[:points] ||= {}
        block[:points][key] = value

        if key =~ /^(ONLY|SKIP|LAST)$/
          block[key] = true
        end
      end
      data << block
    end
    return data
  end
end

#------------------------------------------------------------------------------
# The Runtime object is responsible for running the TestML code and applying it
# to the Ruby test framework (default is Test::Unit).
class TestML::Lite::Runtime
  attr_accessor :test
  attr_accessor :block
  attr_accessor :error

  # TODO runtime base class should not know about Test::Unit @testcase

  def initialize test
    @test = test
  end

  # These methods should be subclassed per test framework as appropriate
  def EQ got, want;end
  def HAS got, want;end
  def OK got;end
  def plan count;end
  def skip;end

  # Run the TestML test!
  def run
    if @test.skip
      @testcase.skip @test.skip
      return
    end
    @count = 0
    @test.function.statements.each {|s| execute(s)}
    if plan = @test.plan
      @testcase.assert_equal plan, @count, "Plan #{plan} tests"
    end
  end

  # Execute an expression/function.
  def execute expr, callback=nil
    get_blocks(expr, test.function.data).each do |block|
      @error = nil
      evaluate expr, block
      raise @error if @error
    end
  end

  # Evaluate a TestML method call.
  def evaluate expr, block
    @block = block
    expr = ['', expr] if expr.kind_of? String
    func = expr.first
    args = expr[1..expr.length-1].collect do |ex|
      if ex.kind_of? Array
        evaluate ex, block
      elsif ex =~ /\A\*(\w+)\z/
        block[:points][$1]
      else
        ex
      end
    end
    return if @error and func != 'Catch'
    # TODO func should not be ''
    return args.first if func.empty?
    begin
      return lookup_method(func).call(*args)
    rescue => e
      @error = e
    end
  end

  def lookup_method func
    return self.method(func) if %w(EQ HAS OK).include? func
    begin return @test.bridge.method(func)
    rescue NameError; end
    begin return @test.library.method(func)
    rescue NameError; end
  end

  # Get the data blocks that apply to an expression.
  def get_blocks expr, data
    want = expr.flatten.grep(/^\*/).collect{|p| p.gsub /^\*/, ''}
    return [nil] if want.empty?
    only = data.select{|block| block['ONLY']}
    data = only unless only.empty?
    blocks = []
    data.each do |block|
      next if block['SKIP']
      ok = true
      want.each do |w|
        unless block[:points][w]
          ok = false
          break
        end
      end
      if ok
        blocks << block
        break if block['LAST']
      end
    end
    return blocks
  end

  def get_label
    return(@block ?
      @block.kind_of?(String) ? @block : @block[:label] :
      "Test ##{@count}"
    )
  end
end

#------------------------------------------------------------------------------
require 'test/unit'

# This is the Runtime class that support Ruby's Test::Unit test framework.
class TestML::Lite::Runtime::Unit < TestML::Lite::Runtime
  # As TestML::Lite objects are created, they get put into this class hash
  # variable keyed by the file name that instantiated them.
  @@Tests = Hash.new
  def self.Tests;@@Tests end

  def self.register test, testname
    if testname
      fail "There is already a test with the name '#{testname}" \
        if TestML::Lite::Runtime::Unit.Tests[testname]
      TestML::Lite::Runtime::Unit.Tests[testname] = test
    end

    # Generate a method that Test::Unit will discover and run. This method will
    # run the tests defined in this TestML::Lite object.
    TestML::Lite::TestCase.send(:define_method, testname) do
      test = TestML::Lite::Runtime::Unit.Tests[testname] \
        or fail "No test object for '#{testname}'"
      test.runtime.testcase = self
      test.run
    end
  end

  attr_accessor :testcase

  def EQ got, want
    @count += 1
    @testcase.assert_equal want, got, get_label
                # TODO Move this logic to testml/diff
                if got != want
                  if respond_to? 'on_fail'
                    on_fail
                  elsif want.match /\n/
                    File.open('/tmp/got', 'w') {|f| f.write got}
                    File.open('/tmp/want', 'w') {|f| f.write want}
                    puts `diff -u /tmp/want /tmp/got`
                  end
                end
  end

  def HAS got, want
    @count += 1
    @testcase.assert_match want, got, get_label
  end

  # TODO Support OK
  def OK got
    @count += 1
    fail 'TODO'
  end
end

# This is the class that Test::Unit will use to run actual tests.  Every time
# that a test file creates a TestML::Lite object, we inject a method called
# "test_#{test_file_name}" into this class, since we know that Test::Unit calls
# methods that begin with 'test'.
class TestML::Lite::TestCase < Test::Unit::TestCase;end

#------------------------------------------------------------------------------
class TestML::Lite::Function
  attr_accessor :statements
  attr_accessor :namespace
  attr_accessor :data

  def initialize
    @signature = []
    @statements = []
    @namespace = {}
    @data = []
  end

  def getvar name
    @namespace[name]
  end

  def setvar name, object
    @namespace[name] = object
  end

  def forgetvar name
    @namespace.delete name
  end
end

#------------------------------------------------------------------------------
class TestML::Lite::Bridge
  attr_accessor :runtime

  def String string
    return super string
  end

  def Number number
    return Integer number
  end
end

#------------------------------------------------------------------------------
class TestML::Lite::Library
  attr_accessor :runtime
end

class TestML::Lite::Library::Standard
  attr_accessor :runtime

  def Throw msg
    @runtime.error = msg
  end

  # TODO @error should probably just be the error message string
  def Catch any=nil
    fail "Catch called, but no error occurred" unless @runtime.error
    error = @runtime.error
    @runtime.error = nil
    return error.respond_to?('message') ? error.message : error
  end
end
