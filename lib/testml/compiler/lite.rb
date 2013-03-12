##
# This is the Lite version of the TestML compiler. It can parse simple
# statements and assertions and also parse the TestML data format.

class TestML::Compiler;end
class TestML::Compiler::Lite
  attr_accessor :function

  POINT = /^\*(\w+)/

  def compile(document)
    @function = TestML::Function.new
    document =~ /\A(.*?)(^===.*)?\z/m or fail;
    code, data = $1 || '', $2 || ''
    while ! code.empty?
      code.sub!(/(.*)\r?\n/, '')
      line = $1
      parse_comment(line) ||
      parse_directive(line) ||
      parse_assignment(line) ||
      parse_assertion(line) ||
        fail("Failed to parse TestML document, here:\n#{line + $/ + code}")
      if ! data.empty?
        @function.data = compile_data(data)
      end
    end
    @function.outer = TestML::Function.new
    return @function
  end

  def parse_comment(line)
    line =~ /^\s*(#|$)/ or return
    return true
  end

  def parse_directive(line)
    line =~ /^%TestML +(\d+\.\d+\.\d+)$/ or return
    @function.setvar('TestML', TestML::Str.new($1))
    return true
  end

  def parse_assignment(line)
    line =~ /^(\w+) *= *(.+?);?$/ or return
    key, value = $1, $2
    value.sub!(/^(['"])(.*)\1$/, $2)
    value = value.match(/^\d+$/) \
      ? TestML::Num.new(value)
      : TestML::Str.new(value)
    @function.statements << TestML::Statement.new(
      TestML::Expression.new([
        TestML::Call.new('Set', [
          key, TestML::Expression.new([ value ]),
        ]),
      ])
    )
    return true
  end

  def parse_assertion(line)
    line =~ /^.*(?:==|~~).*;?$/ or return
    @function.statements << compile_assertion(line.sub /;$/, '')
    return true
  end

  def compile_assertion(expr, points=[])
    left, op, right = TestML::Expression.new, nil, nil
    side = left
    assertion = nil
    while ! expr.empty?
      token = get_token!(expr)
      case token
      when POINT
        side.calls << make_call(token, points)
      when /^(==|~~)$/
        name = token == '==' ? 'EQ' : 'HAS'
        left = side
        side = right = TestML::Expression.new
        assertion = TestML::Assertion.new(name, right)
      when Array
        args = token[1..-1].map do |arg|
          arg =~ /\./ \
            ? compile_assertion(arg, points)
            : make_call(arg, points)
        end
        call = TestML::Call.new(token[0], args, true)
        side.calls << call
      when TestML::Object
        side.calls << token
      else
        XXX expr, token
      end

    end
    right = side if right
    return left unless right
    # left = left.calls.first if left.calls.size == 1
    # right = right.calls.first if right.calls.size == 1
    points = points.uniq
    statement = TestML::Statement.new(
      left,
      assertion,
      (!points.empty? ? points : nil),
    )
    return statement
  end

  def make_call token, points
    case token
    when POINT
      name = $1
      points << name
      return TestML::Point.new(name)
    when String
      return TestML::Str.new(token)
    else
      return token
    end
  end

  def get_token! expr
    if expr.sub! /^(\w+)\(([^\)]+)\)\.?/, ''
      token, args = [$1], $2
      token.concat(
        args.split(/,\s*/).map do |t|
          (t =~ /^(\w+)$/) ? TestML::Expression.new([TestML::Call.new($1)]) :
            (t =~ /^(['"])(.*)\1$/) ? $2 : t
        end
      )
    elsif expr.sub! /^\s*(==|~~)\s*/, ''
      token = $1
    elsif expr.sub! /^(['"])(.*?)\1/, ''
      token = TestML::Str.new($2)
    elsif expr.sub! /^(\d+)/, ''
      token = TestML::Num.new($1)
    elsif expr.sub! /^(\*\w+)\.?/, ''
      token = $1
    elsif expr.sub! /^(\w+)\.?/, ''
      token = [$1]
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
