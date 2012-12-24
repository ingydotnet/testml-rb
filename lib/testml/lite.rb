require 'test/unit'

    # XXX
    require 'pp'
    require 'yaml'; def XXX object; fail YAML.dump object; end

# Make sure tests have access to the application libs and the testing
# libs.
$:.unshift "#{Dir.getwd}/lib"
$:.unshift "#{Dir.getwd}/test/lib"

# Define the base TestML module. TestML Helper class functions can go
# here.
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

  # Skip the test file unless we can require the requisite library(s)
  def self.require_or_skip library, *libraries
    libraries.unshift library
    libraries.each do |lib|
      begin
        require lib
      rescue
        exit
      end
    end
  end

  # Find the first call stack entry that looks like:
  # .../test/xxx-yyy.rb
  def self.get_test_file
    caller.map { |s|
      s.split(':').first
    }.grep(/(^|\/)test\/[-\w]+\.rb$/).first or fail
  end

  # Return something like 'test_xxx_yyy' as the test name.
  def self.get_test_name
    name = TestML.get_test_file
    name.gsub!(/^(?:.*\/)?test\/([-\w+]+)\.rb$/, '\1').gsub(/[^\w]+/, '_')
    return "test_#{name}"
  end
end

# This is the class that Test::Unit will use to run actual tests.
# Every time that a test file creates a TestML::Test object, we
# inject a method called "test_#{test_file_name}" into this class,
# since we know that Test::Unit calls methods that begin with 'test'.
class TestML::TestCase < Test::Unit::TestCase
  def runner name
    test = TestML.Tests[name]
    test._testcase = self
    test._run
  end
end

# Test files create TestML::Test objects, which inject runner methods
# into TestML::TestCase so they will get caalled later. Each
# TestML::Test object contains all the information needed by
# testml to run a test.
class TestML::Test
  attr_accessor :tmlfile
  attr_accessor :bridge
  attr_accessor :document
  attr_accessor :function
  attr_accessor :blocks
  attr_accessor :plan
  attr_accessor :_testcase
  def initialize test_name=nil
    # First order of business is to register this test object so that
    # it can be called by the generated Test::Unit method later on.
    @testfile = TestML.get_test_file
    test_name ||= TestML.get_test_name
    TestML.Tests[test_name] = self

    # Generate a method that Test::Unit will discover and run. This
    # method will run the tests defined in this TestML::Test object.
    TestML::TestCase.send(:define_method, test_name) do
      runner test_name
    end

    # Initialize the object attributes:
    @function = []
    @blocks = []
    # Let caller initialize attributes:
    yield self if block_given?
  end

  # Finalize TestML::Test object, since user may have added things
  # since construction time. After this we can run the test.
  def _finalize
    @bridge ||= TestML::Bridge
    @bridge = @bridge.new unless @bridge.is_a? TestML::Bridge
    @function = [@function] unless @function.class == Array
    if @tmlfile
      if not @tmlfile.match /^\//
        @tmlfile = "#{File.dirname @testfile}/#{@tmlfile}"
      end
      @document = File.read @tmlfile
      @tmlfile = nil
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
  end

  # Finalize the test object, run all the functions, check the plan
  def _run
    _finalize
    @count = 0
    @function.each {|f| _execute(f)}
    if @plan
      _testcase.assert_equal @plan, @count, "Plan #{@plan} tests"
    end
  end

  #------------------------------------------------------------------
  module Runtime
    def _equal got, want, block
      @count += 1
      block ||= {:label => "Test ##{@count}"}
      label = block.kind_of?(String) ? block : block[:label]
      if got != want
        if respond_to? 'on_fail'
          on_fail
        elsif want.match /\n/
          File.open('/tmp/got', 'w') {|f| f.write got}
          File.open('/tmp/want', 'w') {|f| f.write want}
          puts `diff -u /tmp/want /tmp/got`
        end
      end
      _testcase.assert_equal want, got, label
    end

    def _match got, want, block
      @count += 1
      label = block.kind_of?(String) ? block : block[:label]
      _testcase.assert_match want, got, label
    end

    def _execute expr, callback=nil
      expr = @compiler.parse_expr expr if expr.kind_of? String
#       callback ||= method '_run_test'
      _get_blocks(expr).each do |block|
        $error = nil
#         callback.call(block, expr)
        _evaluate expr, block
        raise $error if $error
      end
    end

#     def _run_test block, expr
#       expr = @compiler.parse_expr expr if expr.kind_of? String
#       block = _get_blocks(expr, [block]).first or return
#       _evaluate expr, block
#     end

    def _evaluate expr, block
      expr = ['', expr] if expr.kind_of? String
      func = expr.first
      args = expr[1..expr.length-1].collect do |ex|
        if ex.kind_of? Array
          _evaluate ex, block
        elsif ex =~ /\A\*(\w+)\z/
          block[:points][$1]
        else
          ex
        end
      end
      # TODO @error
      return if $error and func != 'Catch'
      return args.first if func.empty?
      if %w(Equal Match).include? func
        args << block
        method = self.method("_#{func.downcase}")
      else
        method = @bridge.method(func)
      end
      begin
        return method.call(*args)
      rescue => e
        $error = e
      end
    end

    def _get_blocks expr, blocks=@blocks
      want = expr.flatten.grep(/^\*/).collect{|ex| ex.gsub /^\*/, ''}
      return [nil] if want.empty?
      only = blocks.select{|block| block['ONLY']}
      blocks = only unless only.empty?
      final = []
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
          final << block
          break if block['LAST']
        end
      end
      return final
    end
  end
  include Runtime
end

class TestML::Compiler
  attr_accessor :function
  attr_accessor :blocks
  attr_accessor :plan
  attr_accessor :testml_version

  def parse_document document
    @function = []
    @blocks = []
    lines = document.lines.to_a.map{|_|_.chomp}
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
      token = _get_token expr
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

  def _get_token expr
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

class TestML::Bridge
  def Catch any=nil
    fail "Catch called, but no error occurred" unless $error
    error = $error
    $error = nil
    return error.message
  end

  def String string
    return super string
  end

  def Number number
    return Integer number
  end
end
