# Make sure tests have access to the application libs and the testing libs.
$:.unshift Dir.getwd + '/lib'
$:.unshift Dir.getwd + '/test/lib'

require 'test/unit'

module TestML
  def self.run &runner
    name = _get_test_name
    $testml_runners[name] = runner
    TestML::Lite::TestCases.send(:define_method, name) do
      _run_runner name
    end
  end

  def self.data data
    $testml_data[_get_test_name] = data
  end

  def self.require_or_skip module_
    require module_
    rescue exit
  end
end

$testml_runners ||= {}
$testml_data ||= {}

class TestML::Lite < Test::Unit::TestCase
  def data input
    unless input.match /\n/
      File.open(input, 'r') {|f| input = f.read}
    end
    @testml = _parse_tml input
  end

  def label text
    @label = text
  end

  def eval expr, callback=nil
    _assert_testml
    expr = _parse_expr expr if expr.kind_of? String
    callback ||= method 'run_test'
    _get_blocks(expr).each do |block|
      $error = nil
      callback.call(block, expr)
      raise $error if $error
    end
  end

  def run_test block, expr
    expr = _parse_expr expr if expr.kind_of? String
    block = _get_blocks(expr, [block]).first or return
    _evaluate expr, block
  end

  def assert_equal got, want, block
    label = block.kind_of?(String) ? block : block[:title]
    if got != want
      on_fail if respond_to? 'on_fail'
      File.open('/tmp/got', 'w') {|f| f.write got}
      File.open('/tmp/want', 'w') {|f| f.write want}
      puts `diff -u /tmp/want /tmp/got`
    end
    super want, got, label
  end

  def assert_match got, want, block
    label = block.kind_of?(String) ? block : block[:title]
    super want, got, label
  end

  def Catch any=nil
    fail "Catch called, but no error occurred" unless $error
    error = $error
    $error = nil
    return error.message
  end

  def _run_runner name
    @test_name = name
    $testml_runners[name].call(self)
  end

  def _assert_testml
    return if defined? @testml
    raise "No testml data provided" unless $testml_data[@test_name]
    data $testml_data[@test_name]
  end

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
    args << block if func =~ /^assert_/
    begin
      return method(func).call(*args)
    rescue => e
      $error = e
    end
  end

  def _get_blocks expr, blocks=@testml
    want = expr.flatten.grep(/^\*/).collect{|ex| ex.gsub /^\*/, ''}
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

  def _parse_expr expr
    left, op, right = [], nil, nil
    side = left
    while expr.length != 0
      t = _get_token expr
      if t =~ /^(==|~~)$/
        op = t == '==' ? 'assert_equal' : 'assert_match'
        left = side
        side = right = []
      else
        side = [side] if side.size >= 2
        side.unshift t
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
    elsif expr.sub! /^([\*\w]+)\.?/, ''
      token = $1
    end
    return token
  end

  def _parse_tml string
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
        or fail "No block title! #{string_block}"
      block[:title] = $1
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

# Find the first call stack entry that looks like: .../test/xxx-yyy.rb
# and return 'test_xxx_yyy' as the test name.
def _get_test_name
  name = caller.map { |s|
    s.split(':').first
  }.grep(/(^|\/)test\/[-\w]+\.rb$/).first or fail
  name.gsub!(/^(?:.*\/)?test\/([-\w+]+)\.rb$/, '\1').gsub(/[^\w]+/, '_')
  return "test_#{name}"
end

module TestML::Lite::TestCases;end
