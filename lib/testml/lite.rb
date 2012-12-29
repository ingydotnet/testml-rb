# TestML::Lite - A Simpler Version of TestML


require 'yaml'; def XXX *args; puts YAML.dump_stream args; exit; end


# Make sure tests have access to the application libs and the testing libs.
$:.unshift "#{Dir.getwd}/lib"
$:.unshift "#{Dir.getwd}/test/lib"

# Define the base TestML module, with a few helper class methods.
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

# Test files create TestML::Lite objects, which contain all the information
# needed by TestML to run a test.
class TestML::Lite
  VERSION = '0.0.2'

  # These attributes are the API for TestML::Lite.
  attr_accessor :assertions
  attr_accessor :blocks
  attr_accessor :plan
  attr_accessor :skip

  attr_accessor :testname
  attr_accessor :compiler_class
  attr_accessor :runtime_class

  attr_accessor :function
  attr_accessor :runtime
  attr_accessor :bridge

  def initialize attributes={}
    # Initialize the object attributes with defaults:
    @testfile = TestML.get_testfile
    @testname = TestML.get_testname
    @compiler_class = TestML::Lite::Compiler
    @runtime_class = TestML::Lite::Runtime::Unit
    @bridge = TestML::Lite::Bridge.new
    @assertions = []
    @blocks = []
    @plan = nil
    @skip = false
    @run = false
    @function = TestML::Lite::Function.new

    # Set named attributes:
    attributes.each { |k,v| self.send "#{k}=", v }

    # Run caller block if given
    yield self if block_given?

    # Register this test object so that it can be called by the generated
    # Test::Unit method later on.
    @testname ||= TestML.get_testname
    @runtime_class.register self, @testname
    @runtime = @runtime_class.new self
  end

  def bridge= bridge
    @bridge = (bridge.is_a? TestML::Lite::Bridge) ? bridge : bridge.new
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
    @function.blocks = @blocks if not @blocks.empty?
    @function.setvar('Plan', @plan) if @plan
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

# This is the Lite version of the TestML compiler. It can parse
# simple statements and assertions and also parse the TestML data
# format.
class TestML::Lite::Compiler
  attr_accessor :function
  attr_accessor :plan
  attr_accessor :testml_version

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
      elsif line.strip.match /^Plan *= *(\d+)$/
        @function.setvar('Plan', $1.to_i)
      elsif line.strip.match /^.*(?:==|~~).*$/
        @function.statements << compile_assertion(line)
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
        op = token == '==' ? 'Equal' : 'Match'
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

    array = []
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
      array << block
    end
    return array
  end
end

#------------------------------------------------------------------------------
# The Runtime object is responsible for running the TestML code and applying it
# to the Ruby test framework (default is Test::Unit).
class TestML::Lite::Runtime
  attr_accessor :test

  def initialize test
    @test = test
  end

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
      # TODO eliminate this global variable.
      $TestMLError = nil
      evaluate expr, block
      raise $TestMLError if $TestMLError
    end
  end

  # Evaluate a TestML method call.
  def evaluate expr, block
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
    return if $TestMLError and func != 'Catch'
    return args.first if func.empty?
    if %w(Equal Match).include? func
      args << block
      method = self.method(func)
    else
      method = @test.bridge.method(func)
    end
    begin
      return method.call(*args)
    rescue => e
      $TestMLError = e
    end
  end

  # Get the data blocks that apply to an expression.
  def get_blocks expr, blocks
    want = expr.flatten.grep(/^\*/).collect{|p| p.gsub /^\*/, ''}
    return [nil] if want.empty?
    only = blocks.select{|block| block['ONLY']}
    blocks = only unless only.empty?
    got = []
    blocks.each do |block|
      next if block['SKIP']
      ok = true
      want.each do |w|
        unless block[:points][w]
          ok = false
          break
        end
      end
      if ok
        got << block
        break if block['LAST']
      end
    end
    return got
  end

  def Equal got, want, block
    @count += 1
    label = block ?
      block.kind_of?(String) ? block : block[:label] :
      "Test ##{@count}"
    if got != want
      if respond_to? 'on_fail'
        on_fail
      elsif want.match /\n/
        File.open('/tmp/got', 'w') {|f| f.write got}
        File.open('/tmp/want', 'w') {|f| f.write want}
        puts `diff -u /tmp/want /tmp/got`
      end
    end
    @testcase.assert_equal want, got, label
  end

  def Match got, want, block
    @count += 1
    label = block ?
      block.kind_of?(String) ? block : block[:label] :
      "Test ##{@count}"
    @testcase.assert_match want, got, label
  end
end

#------------------------------------------------------------------------------
require 'test/unit'

# This is the class that Test::Unit will use to run actual tests.  Every time
# that a test file creates a TestML::Lite object, we inject a method called
# "test_#{test_file_name}" into this class, since we know that Test::Unit calls
# methods that begin with 'test'.
class TestML::Lite::TestCase < Test::Unit::TestCase;end

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

end

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

class TestML::Lite::Bridge
  def Catch any=nil
    fail "Catch called, but no error occurred" unless $TestMLError
    error = $TestMLError
    $TestMLError = nil
    return error.message
  end

  def String string
    return super string
  end

  def Number number
    return Integer number
  end
end
