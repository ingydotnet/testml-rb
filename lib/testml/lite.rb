require 'test/unit'

# Make sure tests have access to the application libs and the testing
# libs.
$:.unshift "#{Dir.getwd}/lib"
$:.unshift "#{Dir.getwd}/test/lib"

# Define the base TestML module, with a few helper class methods.
module TestML
  # TestML::Lite class does nothing, but let's put the VERSION here.
  class Lite
    VERSION = '0.0.2'
  end

  # As TestML::Test objects are created, they get put into this class
  # hash variable keyed by the file name that instantiated them.
  @@Tests = Hash.new
  def self.Tests
    @@Tests
  end

  # Find the first call-stack entry that looks like:
  # .../test/xxx-yyy.rb
  def self.get_testfile
    caller.map { |s|
      s.split(':').first
    }.grep(/(^|\/)test\/[-\w]+\.rb$/).first or fail
  end

  # Return something like 'test_xxx_yyy' as the test name.
  def self.get_testname
    name = TestML.get_testfile
    name.gsub!(/^(?:.*\/)?test\/([-\w+]+)\.rb$/, '\1').gsub(/[^\w]+/, '_')
    return "test_#{name}"
  end
end

# This is the class that Test::Unit will use to run actual tests.
# Every time that a test file creates a TestML::Test object, we
# inject a method called "test_#{test_file_name}" into this class,
# since we know that Test::Unit calls methods that begin with 'test'.
class TestML::TestCase < Test::Unit::TestCase;end

# Test files create TestML::Test objects, which inject runner methods
# into TestML::TestCase so they will get caalled later. Each
# TestML::Test object contains all the information needed by
# testml to run a test.
class TestML::Test
  # These attributes are the API for TestML::Test.
  attr_accessor :testname
  attr_accessor :tmlfile
  attr_accessor :bridge
  attr_accessor :document
  attr_accessor :function
  attr_accessor :blocks
  attr_accessor :plan
  attr_accessor :skip

  # Private attributes
  attr_accessor :compiler
  attr_accessor :runtime

  def initialize attributes={}
    # Set named attributes:
    attributes.each { |k,v| self.send "#{k}=", v }

    # First order of business is to register this test object so that
    # it can be called by the generated Test::Unit method later on.
    @testfile = TestML.get_testfile
    testname = @testname ||= TestML.get_testname
    TestML.Tests[@testname] = self

    # Generate a method that Test::Unit will discover and run. This
    # method will run the tests defined in this TestML::Test object.
    TestML::TestCase.send(:define_method, testname) do
      test = TestML.Tests[testname] \
        or fail "No test object for '#{testname}'"
      test.finalize
      test.runtime.testcase = self
      test.runtime.run
    end

    # Initialize the object attributes:
    @function = []
    @blocks = []
    # Let caller initialize attributes:
    yield self if block_given?
  end

  # Finalize TestML::Test object, since user may have added things
  # since construction time. After this we can run the test.
  def finalize
    @bridge ||= TestML::Bridge
    @bridge = @bridge.new unless @bridge.is_a? TestML::Bridge
    @function = [@function] unless @function.class == Array
    if @tmlfile
      if not @tmlfile.match /^\//
        @tmlfile = "#{File.dirname @testfile}/#{@tmlfile}"
      end
      @document = File.read @tmlfile
    end
    @compiler = TestML::Compiler.new
    if @document
      @compiler.parse_document @document
      @function.concat @compiler.function
      @blocks.concat @compiler.blocks
      @plan = @compiler.plan
    end
    @function.map! do |f|
      f.class == String ? @compiler.parse_expr(f) : f
    end
    @runtime = TestML::Runtime.new(self)
  end

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
class TestML::Compiler
  attr_accessor :function
  attr_accessor :blocks
  attr_accessor :plan
  attr_accessor :testml_version

  def parse_document document
    @function = []
    @blocks = []
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
      elsif line.strip.match /^Plan *= *(\d+);$/
        @plan = $1.to_i
      elsif line.strip.match /^.*(?:==|~~).*;$/
        @function << line.chop
      else
        lines.unshift line
        fail "Failed to parse TestML document, here:\n" +
          lines.join($/)
      end
    end
    unless lines.empty?
      @blocks = parse_data lines.push('').join $/
    end
  end

  def parse_expr expr
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

  def parse_data string
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

# The Runtime object is responsible for running the TestML code and
# applying it Ruby's Test::Unit.
class TestML::Runtime
  attr_accessor :testcase

  def initialize(test)
    @test = test
  end

  def run
    if @test.skip
      @testcase.skip @test.skip
      return
    end
    @count = 0
    @test.function.each {|f| execute(f)}
    if plan = @test.plan
      @testcase.assert_equal plan, @count, "Plan #{plan} tests"
    end
  end

  # Execute an expression/function.
  def execute expr, callback=nil
    get_blocks(expr).each do |block|
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
  def get_blocks expr, blocks=@test.blocks
    want = expr.flatten.grep(/^\*/).collect{|ex| ex.gsub /^\*/, ''}
    return [nil] if want.empty?
    only = blocks.select{|block| block['ONLY']}
    blocks = only unless only.empty?
    found = []
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
        found << block
        break if block['LAST']
      end
    end
    return found
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

class TestML::Bridge
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
